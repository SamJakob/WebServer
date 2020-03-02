//
//  Server.h
//  WebServer
//
//  Created by Sam Mearns on 2/28/20.
//  Copyright © 2020 Apollo Software. All rights reserved.
//

#ifndef Server_h
#define Server_h

#import "ReqRes.h"
#import "RequestHandler.h"
#import "WebSocket.h"

@interface Server : NSObject {
    /// The port number that the webserver should run on.
    unsigned int port;
    
@private
    /// Whether or not the server should continue listening to connections.
    /// This is set to false by calling halt.
    bool _listening;
    
    /// The file descriptor of the POSIX server socket.
    int serverFd;
    
    /// The dispatch group for handling connections to the server.
    dispatch_group_t serverConnectionsGroup;
    
    /// The array of request handlers.
    NSMutableArray<RequestHandler*> *handlers;
    
    /// The dictionary of websocket handlers (mapping path to handler)
    NSMutableDictionary<NSString*, WebSocketConnectionBlock> *socketHandlers;
    
    /// The array of connected sockets - used to avoid handshaking multiple times and to pass socket communications to
    /// the correct socket handler.
    NSMutableArray<WebSocket*> *webSockets;
}

/// Whether or not the server is listening on a given port.
@property (readonly) bool listening;

-(instancetype) init:(unsigned int) _port;
-(void) start;
-(void) start:(bool) block;
-(void) halt;

-(void) on:(Method) method path:(NSString*) path execute:(RequestBlock) block;
-(void) onWebSocketConnection:(NSString*) path execute:(WebSocketConnectionBlock) block;
@end

#endif /* Server_h */
