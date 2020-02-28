//
//  Server.m
//  WebServer
//
//  Created by Sam Mearns on 2/28/20.
//  Copyright © 2020 Apollo Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <sys/socket.h>
#import <netinet/in.h>

#import "Server.h"
#import "ReqRes.h"
#import "RequestHandler.h"

@implementation Server : NSObject

@synthesize listening = _listening;

-(instancetype) init:(unsigned int) _port {
    if(self = [super init]){
        // Initialize self.
        port = _port;
        handlers = [[NSMutableArray alloc] init];
        _listening = false;
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
    // int soReusePort = 1;
    // setsockopt(serverFd, SOL_SOCKET, SO_REUSEPORT, &soReusePort, sizeof(soReusePort));
    
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
                [self callHandlers:clientFd forRequest: request];
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
    
    // If the request method is invalid, simply return a 405 (Method Not Allowed)
    if(request.method == NULL){
        
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
    write(socket, buffer, [payload length]);
    close(socket);
    
}

-(void) on:(Method) method path:(NSString*) path execute:(RequestBlock) block {
    
    RequestHandler *handler = [[RequestHandler alloc] init:(Method) method forPath:(NSString*) path andWithBlock:(RequestBlock) block];
    [handlers addObject:handler];
    
}

-(void) halt {
    self->_listening = false;
    
    close(self->serverFd);
    self->serverFd = -1;
}
@end
