//
//  Server.m
//  WebServer
//
//  Created by Sam Mearns on 2/28/20.
//  Copyright © 2020 Apollo Software. All rights reserved.
//

#include <Foundation/Foundation.h>
#include <CommonCrypto/CommonCrypto.h>
#include <sys/socket.h>
#include <netinet/in.h>

#include "ReqRes.h"
#include "RequestHandler.h"
#include "WebSocket.h"
#include "Server.h"

#include <curses.h>

@implementation Server : NSObject

@synthesize listening = _listening;

-(instancetype) init:(unsigned int) _port {
    if(self = [super init]){
        // Initialize self.
        handlers = [[NSMutableArray alloc] init];
        socketHandlers = [[NSMutableDictionary alloc] init];
        
        _listening = false;
        port = _port;
        webSockets = [[NSMutableArray alloc] init];
    }
    
    return self;
}

-(void) start {
    // Block the main thread by default.
    [self start:true];
}

/// @method start
/// @abstract Starts the server.
/// @discussion While the execution is run in a dispatch group on Grand Central Dispatch's
/// concurrent execution queue, if nothing is running on the main thread, the application will simply
/// terminate without processing any requests. As this is obviously undesired behavior, a block
/// parameter has been provided that will block the main thread using dispatch_group_wait - if the
/// block parameter is set to true to prevent the application from terminating.
-(void) start:(bool) block {
    
    if (_listening) {
        return;
    }
    
    // Declare the server socket address.
    struct sockaddr_in serverAddress;
    memset(&serverAddress, 0, sizeof(serverAddress));
    
    serverAddress.sin_family = AF_INET; // IPv4
    serverAddress.sin_addr.s_addr = htonl(INADDR_ANY);
    serverAddress.sin_port = htons(self->port);
    
    // Initialize the server socket and set socket options.
    self->serverFd = socket(AF_INET, SOCK_STREAM, 0);
    if (self->serverFd == -1) {
        return;
    }
    
    /// This may be useful for development (it will allow you to bypass the TIME_WAIT after a socket closes):
    int soReusePort = 0;
    if (soReusePort) {
        setsockopt(serverFd, SOL_SOCKET, SO_REUSEPORT, &soReusePort, sizeof(soReusePort));
        
        move(12, 0);
        addstr("SECURITY WARNING: SO_REUSEPORT = 1");
        move(0, 0);
    }
    
    // Start listening for connections.
    if(bind(serverFd, (struct sockaddr*) &serverAddress, sizeof(serverAddress)) == -1){
        return;
    }
    
    _listening = true;
    listen(serverFd, 10 /** = backlog. (The maximum number of pending connections to queue.) */);
    
    // Prepare Grand Central Dispatch.
    self->serverConnectionsGroup = dispatch_group_create();
        
    dispatch_group_async(serverConnectionsGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        while (self->_listening) {
            // Accept a connection from the client socket.
            __block int clientFd = accept(self->serverFd, (struct sockaddr*) NULL, NULL);
            if(!self->_listening) return;
            
            dispatch_group_async(self->serverConnectionsGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                // Receive payload from the client socket.
                char buffer[1024];
                bzero(buffer, 1024);
                
                NSString *payload = @"";
                bool continueReading = true;
                
                do {
                    recv(clientFd, buffer, 1024, 0);
                    unsigned long size = strlen(buffer);
                    
                    payload = [NSString stringWithFormat:@"%@%s", payload, buffer];
                    
                    if(buffer[size - 2] == '\r' && buffer[size - 1] == '\n'){
                        continueReading = false;
                    }
                } while (continueReading);
                
                // Parse the payload.
                NSMutableArray *payloadLines = [[payload componentsSeparatedByString:@"\r\n"] mutableCopy];
                
                // Process the payload HTTP start line.
                NSString *startLine = payloadLines[0];
                NSArray *startLineComponents = [startLine componentsSeparatedByString:@" "];
                
                [payloadLines removeObjectAtIndex:0];
                
                // Setup the request information.
                struct request_data requestData;
                requestData.method = startLineComponents[0];
                requestData.path = startLineComponents[1];
                requestData.httpVersion = startLineComponents[2];
                requestData.headers = payloadLines;
                
                Request *request = [[Request alloc] init: &requestData];
                
                /* START: Perform WebSocket checks */
                bool isWebSocket = true;
                
                /**
                 Check 1: the HTTP version must be greater than or equal to HTTP/1.1 (the only two older versions are HTTP 0.9 and HTTP 1.0)
                 */
                isWebSocket &= !([request.httpVersion isEqualToString:@"HTTP/0.9"] || [request.httpVersion isEqualToString:@"HTTP/1.0"]);
                
                /**
                 Check 2: The HTTP method MUST be GET.
                 */
                isWebSocket &= request.method == GET;
                
                /**
                 Check 3: The appropriate Upgrade headers must be present.
                 */
                isWebSocket &= [[[request header:@"connection"] lowercaseString] isEqualToString:@"upgrade"];   // Connection: Upgrade
                isWebSocket &= [[[request header:@"upgrade"] lowercaseString] isEqualToString:@"websocket"];    // Upgrade: websocket
                
                /**
                 Check 4: The Sec-WebSocket-Key header must be present.
                 */
                isWebSocket &= [request header:@"Sec-WebSocket-Key"] != NULL;
                /* END: Perform WebSocket checks */
                
                if (isWebSocket) {
                    
                    // Perform the initial handshake.
                    NSString *key = [request header:@"Sec-WebSocket-Key"];
                    NSString *acceptance = [NSString stringWithFormat:@"%@%@", key, WS_MAGIC_STRING];
                    
                    const char *data = [acceptance UTF8String];
                    
                    // Compute an SHA1 digest of the acceptance string to produce a valid
                    // Sec-WebSocket-Accept header.
                    unsigned char digest[CC_SHA1_DIGEST_LENGTH];
                    CC_SHA1(data, (CC_LONG) strlen(data), digest);
                    
                    NSData *digestData = [[NSData alloc] initWithBytes:digest length:sizeof(digest)];
                    NSString *accept = [digestData base64EncodedStringWithOptions:0/** = no options */];
                    
                    // Send the HTTP acknowledgement for WebSocket communications.
                    NSMutableString *ackPayload = [[NSMutableString alloc] initWithString:@"HTTP/1.1 101 Switching Protocols\r\n"];
                    [ackPayload appendString:@"Upgrade: websocket\r\n"];
                    [ackPayload appendString:@"Connection: Upgrade\r\n"];
                    [ackPayload appendFormat:@"%@%@%@", @"Sec-WebSocket-Accept: ", accept, @"\r\n"];
                    [ackPayload appendString:@"\r\n"];
                    
                    const char* buffer = [ackPayload UTF8String];
                    write(clientFd, buffer, strlen(buffer));
                    
                    WebSocket *socket = [[WebSocket alloc] init:clientFd performDispatchTasksOn:self->serverConnectionsGroup];
                    [self->webSockets addObject:socket];
                    
                    // Now hand over control to the WebSocket handler.
                    // TODO: Implement WebSocket handler APIs.
                    
                } else {
                    
                    // Call the request handlers to compute the response.
                    [self callHandlers:clientFd forRequest: request];
                    
                }
                
            });
        }
        
        close(self->serverFd);
        dispatch_group_leave(self->serverConnectionsGroup);
    });
    
    if(block) dispatch_group_wait(serverConnectionsGroup, DISPATCH_TIME_FOREVER);
    
}

-(void) callHandlers:(int) socket forRequest: (Request*) request {
    
    Response *response = [[Response alloc] init];
    // Set default response headers...
    [response setHeader:@"Transfer-Encoding" value:@"identity"];
    [response setHeader:@"Content-Type" value:@"text/html"];
    [response setHeader:@"Connection" value:@"Close"];
    
    if(request.method == NULL){
        
        // If the request method is invalid, simply return a 405 (Method Not Allowed)
        [response status:@405];
        
    } else {
        for(RequestHandler *handler in handlers){
            if([handler shouldExecuteFor:request]) [handler execute:request response:response];
        }
    }
    
    // Compute status line and thus initial payload.
    NSNumber *status = response->status;
    NSMutableString *payload = [NSMutableString stringWithFormat:@"%@ %@\r\n", request.httpVersion, status];
    
    // Next, determine the response output.
    NSString *body;
    /// If the status is 201 or 204, we don't need a request body.
    if(![status isEqual:@201] && ![status isEqual:@204]) body = response->output;
    [response setHeader:@"Content-Length" value:[NSString stringWithFormat:@"%lu", [body length]]];
    
    // Then, write the headers to the payload.
    for (NSString* header in response->headers) {
        NSString* value = [response->headers valueForKey:header];
        [payload appendFormat:@"%@: %@\r\n", header, value];
    }
    
    // Write the response output to the body.
    if(body != NULL){
        [payload appendString:@"\r\n"];
    }
    [payload appendString:body];
    
    // Finally, convert this to a buffer and output to the socket.
    const char* buffer = [payload UTF8String];
    write(socket, buffer, strlen(buffer));
    close(socket);
    
}

-(void) on:(Method) method path:(NSString*) path execute:(RequestBlock) block {
    
    RequestHandler *handler = [[RequestHandler alloc] init:(Method) method forPath:(NSString*) path andWithBlock:(RequestBlock) block];
    [handlers addObject:handler];
    
}

-(void) onWebSocketConnection:(NSString*) path execute:(WebSocketConnectionBlock) block {
    
    [socketHandlers setValue:block forKey:path];
    
}

-(void) halt {
    self->_listening = false;
    
    close(self->serverFd);
    self->serverFd = -1;
}
@end
