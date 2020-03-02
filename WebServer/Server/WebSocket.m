//
//  WebSocket.m
//  WebServer
//
//  Created by Sam Mearns on 3/1/20.
//  Copyright © 2020 Apollo Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <sys/socket.h>
#include <netinet/in.h>

#import "WebSocket.h"

@implementation WebSocket : NSObject

-(instancetype) init:(int) socketDescriptor performDispatchTasksOn:(dispatch_group_t) dispatchGroup {
    self = [super init];
    if (self) {
        self->socketDescriptor = socketDescriptor;
        
        // Dispatch task to receive WebSocket frames and manage WebSocket communications.
        dispatch_group_async(dispatchGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            // Read lead in bits: 0 - 3: [FIN, RSV{1-3}], 4 - 7: [opcode]
            unsigned char leadIn[1];
            recv(socketDescriptor, leadIn, 1, 0);
            
            unsigned char opcode = 0;
            opcode += (leadIn[0] & 0x8) << 3;
            opcode += (leadIn[0] & 0x4) << 2;
            opcode += (leadIn[0] & 0x2) << 1;
            opcode += (leadIn[0] & 0x1) << 0;
            
            // Read payload length
            unsigned char payloadLengthBytes[1];
            recv(socketDescriptor, payloadLengthBytes, 1, 0);
            
            // This will almost certainly be 1 when coming from the client
            // as is defined in the specification.
            bool masked = payloadLengthBytes[0] & 0x80;
            
            // Read the first payload length.
            unsigned long payloadLength = 0;
            payloadLength += (payloadLengthBytes[0] & 0x40);
            payloadLength += (payloadLengthBytes[0] & 0x20);
            payloadLength += (payloadLengthBytes[0] & 0x10);
            payloadLength += (payloadLengthBytes[0] & 0x8);
            payloadLength += (payloadLengthBytes[0] & 0x4);
            payloadLength += (payloadLengthBytes[0] & 0x2);
            payloadLength += (payloadLengthBytes[0] & 0x1);
            
            // If the initial payload length is 126, read the next 16 bits
            // and interpret those as an unsigned integer.
            if(payloadLength == 126) {
                
                unsigned char newPayloadLengthBytes[2];
                recv(socketDescriptor, newPayloadLengthBytes, 2, 0);
                
                payloadLength = 0;
                payloadLength += newPayloadLengthBytes[0] << 8;
                payloadLength += newPayloadLengthBytes[1];
                
            // If the initial payload length is 127, read the next 64 bits
            // and interpret those as an unsigned integer.
            } else if (payloadLength == 127) {
                
                unsigned char newPayloadLengthBytes[8];
                recv(socketDescriptor, newPayloadLengthBytes, 8, 0);
                
                payloadLength = 0;
                for(int i = 0; i < 8; i++)
                    // Grab the left-most byte from the frame, shift it left for the long value
                    // and then add it to the long value.
                    payloadLength += (newPayloadLengthBytes[8 - i] << (i * 8));
                
            }
            
            // Determine the masking key if it needs to be determined.
            unsigned char maskingKey[4];
            if (masked) {
                // If the data is masked, read the masking key (4 bytes).
                recv(socketDescriptor, maskingKey, 4, 0);
            }
            
            // Now read in the payload.
            unsigned char payload[payloadLength];
            recv(socketDescriptor, payload, payloadLength, 0);
            
            // (If the payload is masked, we need to decode it.)
            if (masked) {
                for(int i = 0; i < payloadLength; i++){
                    payload[i] = payload[i] ^ maskingKey[i % 4];
                }
            }
            
            // TODO: Payload is recieved correctly. Now we have to actually do stuff with it!
            NSLog(@"%s", payload);
            
        });
    }
    
    return self;
}

-(bool) represents:(int) socketDescriptor {
    return self->socketDescriptor == socketDescriptor;
}

@end
