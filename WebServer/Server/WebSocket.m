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
        self->dispatchGroup = dispatchGroup;
        self->socketDescriptor = socketDescriptor;
        self->messageHandlers = [[NSMutableArray alloc] init];
        
        // Dispatch task to receive WebSocket frames and manage WebSocket communications.
        dispatch_group_async(dispatchGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            // Because WebSockets has an explicit disconnect handshake, we will assume that
            // the connection is still active unless a ping fails.
            while (true) {
                // Continuously attempt to read data from the socket (without dequeueing - MSG_PEEK)
                // and if it is present, process the WebSocket frame.
                if(recv(self->socketDescriptor, NULL, 1, MSG_PEEK) != 0){
                    // Read lead in bits: 0 - 3: [FIN, RSV{1-3}], 4 - 7: [opcode]
                    unsigned char leadIn[1];
                    recv(socketDescriptor, leadIn, 1, 0);
                    
                    bool isFinal = (leadIn[0] & 0x80);
                    bool reserveBit1 = (leadIn[0] & 0x40);
                    bool reserveBit2 = (leadIn[0] & 0x20);
                    bool reserveBit3 = (leadIn[0] & 0x10);
                    
                    // The reserve bits MUST be 0 unless dictated by extensions and as
                    // we do not implement any extensions that specify a non-zero value,
                    // the connection will be closed if any of the reserve bits are set.
                    if (reserveBit1 || reserveBit2 || reserveBit3) {
                        close(self->socketDescriptor);
                        break;
                    }
                    
                    unsigned char opcode = 0;
                    opcode += (leadIn[0] & 0x8);
                    opcode += (leadIn[0] & 0x4);
                    opcode += (leadIn[0] & 0x2);
                    opcode += (leadIn[0] & 0x1);
                    
                    // Read payload length
                    unsigned char payloadLengthBytes[1];
                    recv(socketDescriptor, payloadLengthBytes, 1, 0);
                    
                    // This will almost certainly be 1 when coming from the client
                    // as is defined in the specification.
                    bool masked = payloadLengthBytes[0] & 0x80;
                    
                    // Per section 5.1 of the specification, if the mask bit is unset from the client side,
                    // (i.e. if the client sends an unmasked message) the server must disconnect the client.
                    // This is included seperately here, so this can be disabled at a later date.
                    if (!masked) {
                        close(self->socketDescriptor);
                        break;
                    }
                    
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
                    
                    // Now we will perform the correct action based on the opcode.
                    if (opcode == 0x00) {
                        // Opcode: 0x00 (continuation)
                        // TODO: Implement continuation.
                    } else if(opcode == 0x01) {
                        // Opcode: 0x01 (text)
                        NSString *payloadString = [[NSString alloc] initWithBytes:payload length:payloadLength encoding:NSUTF8StringEncoding];
                        
                        for (WebSocketMessageBlock messageHandler in self->messageHandlers) {
                            messageHandler(payloadString);
                        }
                    } else if (opcode == 0x02) {
                        // Opcode 0x02 (binary)
                        // Ignored. This is not used by implementations with this library.
                    } else {
                        
                        /* CONTROL FRAMES */
                        // All control frames MUST have a payload length of 125 bytes or less
                        // and MUST NOT be fragmented.
                        
                        if (!isFinal) {
                            // If the control frame is not final, ignore it - as control frames
                            // must not be fragmented.
                            continue;
                        }
                        
                        if (payloadLength > 125) {
                            // If the control frame's payload length is greater than 125
                            // (i.e. not 125 bytes or less), ignore it - as control frames
                            // must have a payload length of 125 or less.
                            continue;
                        }
                        
                        if (opcode == 0x08) {
                            // Opcode: 0x08 (connection close)
                            
                            // Get the close reason
                            const unsigned char reason = payload[0] << 8 | payload[1];
                            
                            [self send:[NSData dataWithBytes:&reason length:2] withOpcode:0x08];
                            close(self->socketDescriptor);
                            break;
                            
                        } else if (opcode == 0x09) {
                            // Opcode: 0x09 (ping)
                            
                        } else if (opcode == 0x0A) {
                            // Opcode: 0x0A (pong)
                            
                        }
                        
                    }
                }
            }
            
        });
    }
    
    return self;
}

-(bool) represents:(int) socketDescriptor {
    return self->socketDescriptor == socketDescriptor;
}

-(void) onMessage:(WebSocketMessageBlock) messageHandler {
    [messageHandlers addObject:messageHandler];
}

/*!
 * Valid opcodes are as follows:
 * 0x00: continuation
 * 0x01: text
 * 0x02: binary
 * 0x09: ping
 * 0x0A: pong
 */
-(void) send:(NSData*) data withOpcode:(unsigned char) opcode {
    
    dispatch_group_async(self->dispatchGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        /* Start: compute leadIn */
        
        // FIN bit. Whether or not the packet is finished.
        bool isFinished = true;
        // The finish bits and reserve bits of the lead-in.
        unsigned char FIN_RSV = (isFinished << 3) | 0b000;
        
        // Thus the entire leadIn is computed.
        unsigned char leadIn = (FIN_RSV << 4) | opcode;
        write(self->socketDescriptor, &leadIn, 1);
        
        /* End: compute leadIn */
        
        // Generate payload bytes.
        const unsigned char *payload = (const unsigned char*) [data bytes];
        
        /* Start: compute packet length */
        
        // The mask bit should be false coming from the server. Furthermore, calculation
        // of masked bits has NOT been implemented.
        bool isMasked = false;
        
        unsigned long payloadLength = [data length];
        unsigned char payloadLengthFirstByte = payloadLength;
        
        // If the payload length is 125 or less, we can just use the first byte
        // to represent the payload length.s
        if (payloadLength <= 125) {
            
            payloadLengthFirstByte = (isMasked << 7) | payloadLength;
            write(self->socketDescriptor, &payloadLengthFirstByte, 1);
            
        // If the payload length is 65,535 or less, we can just use the first 16 bits to
        // represent the payload length (per the specification) and set the first payloadLength
        // byte to 1.
        } else if (payloadLength <= 65535) {
            
            payloadLengthFirstByte = (isMasked << 7) | 126;
            write(self->socketDescriptor, &payloadLengthFirstByte, 1);
            
            // Now calculate and write the next 2 bytes.
            unsigned mask = (1 << 16) - 1; // Generate a bit mask for only the last 16 bits.
            unsigned payloadLengthBits = payloadLength & mask;
            
            write(self->socketDescriptor, &payloadLengthBits, 2);
            
        // Otherwise, it's the size of a long (64 bits) so we'll set payloadLengthFirstByte to 127
        // (per the specification) and just send the entire payloadLength long.
        } else {
            
            payloadLengthFirstByte = (isMasked << 7) | 127;
            write(self->socketDescriptor, &payloadLengthFirstByte, 1);
            
            // Now just write the entire unsigned long (8 bits).
            write(self->socketDescriptor, &payloadLength, 8);
            
        }
        /* End: compute packet length */
        
        // Now we simply write the payload data.
        write(self->socketDescriptor, payload, payloadLength);
        
    });
    
}

-(void) sendString:(NSString*) data {
    
    [self send:[data dataUsingEncoding:NSUTF8StringEncoding] withOpcode:0x01];
    
}

@end
