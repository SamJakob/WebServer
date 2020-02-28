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

@interface Server : NSObject {
    /// The port number that the webserver should run on.
    unsigned int port;
    
    /// The array of request handlers.
    NSMutableArray<RequestHandler*> *handlers;
    
@private
    /// Whether or not the server should continue listening to connections.
    /// This is set to false by calling halt.
    bool _listening;
    
    /// The file descriptor of the POSIX server socket.
    int serverFd;
    
    /// The dispatch group for handling connections to the server.
    dispatch_group_t serverConnectionsGroup;
}

/// Whether or not the server is listening on a given port.
@property (readonly) bool listening;

-(instancetype) init:(unsigned int) _port;
-(void) on:(Method) method path:(NSString*) path execute:(RequestBlock) block;
-(void) start;
-(void) start:(bool) block;
-(void) halt;
@end

#endif /* Server_h */
