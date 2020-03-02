//
//  WebSocket.h
//  WebServer
//
//  Created by Sam Mearns on 3/1/20.
//  Copyright © 2020 Apollo Software. All rights reserved.
//

#ifndef WebSocket_h
#define WebSocket_h

#import "ReqRes.h"

static const NSString *WS_MAGIC_STRING = @"258EAFA5-E914-47DA-95CA-C5AB0DC85B11";

@interface WebSocket : NSObject {
    
    

@private
    /// The POSIX descriptor of the WebSocket connection.
    int socketDescriptor;

}

-(instancetype) init:(int) socketDescriptor performDispatchTasksOn:(dispatch_group_t) dispatchGroup;
-(bool) represents:(int) socketDescriptor;
@end

typedef void (^WebSocketConnectionBlock)(Request* request, WebSocket* socket);

#endif /* WebSocket_h */
