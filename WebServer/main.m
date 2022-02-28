//
//  main.m
//  WebServer
//
//  Created by Sam Mearns on 2/28/20.
//  Copyright © 2020 Apollo Software. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "Console.h"
#import "Server.h"

const unsigned int PORT = 3000;

int main(int argc, const char * argv[]) {
    
    @autoreleasepool {
        Console *console = [[Console alloc] init:@"Console" statusLine:2 promptLine:8];
        
        [console progress:@"%@%u%@", @"⏳ Starting webserver on port ", PORT, @"..."];
        Server *server = [[Server alloc] init: PORT];
        
        [server on:GET path:@"/" execute:^(Request* request, Response* response){
            [response append:@"<h1>Objective-C kinda neat tho</h1>"];
        }];
        
        [server on:GET path:@"/delay" execute:^(Request* request, Response* response){
            [NSThread sleepForTimeInterval:3];
            [response write:@"<p>hi</p>"];
        }];
        
        [server onWebSocketConnection:@"/socket2" execute:^(Request* request, WebSocket* socket){
            
            [socket onMessage:^(NSString* message){
                if ([message isEqualToString:@"ping"]) [socket sendString:@"fatass!"];
                else [socket sendString:message];
            }];
            
        }];
        
        [server onWebSocketConnection:@"/socket" execute:^(Request* request, WebSocket* socket){
            
            [socket onMessage:^(NSString* message){
                if ([message isEqualToString:@"ping"]) [socket sendString:@"Pong!"];
                else [socket sendString:message];
            }];
            
        }];
        
        // The block parameter is set to false as, on account of the CLI,
        // we do not want to block the main thread.
        [server start:false];
        if (server.listening) {
            [console progressEnd:@"%@%u%@", @"🌎 Successfully started webserver on port ", PORT, @"."];
        } else {
            [server halt];
            [console progressEnd:@"🔴 An error occurred whilst starting the webserver."];
        }
         
        [console print:@""];
        [console print:@""]; // Gets replaced with status line.
        [console print:@""];
        [console print:@"start:\t\tStarts the server."];
        [console print:@"stop:\t\tStops the server."];
        [console print:@"exit:\t\tTerminates the application."];
        
        __block bool continueREPL = true;
        while (continueREPL) {
            [console renderStatus:server];
            
            NSString *command = [console prompt:@"Enter command: > "];
            
            (^(NSString* command){
                if([command isEqualToString:@"start"]){
                    if (server.listening) {
                        [console print:@"🔴 The server is already running!"];
                        return;
                    }
                    
                    [console progress:@"⏳ Starting server..."];
                    [server start:false];
                    
                    if (server.listening) {
                        [console progressEnd:@"%@%u%@", @"🌎 Successfully started webserver on port ", PORT, @"."];
                    } else {
                        [server halt];
                        [console progressEnd:@"🔴 An error occurred whilst starting the webserver."];
                    }
                    return;
                }
                
                if([command isEqualToString:@"stop"]){
                    [console progress:@"⏳ Halting server..."];
                    if (!server.listening) {
                        [console progressEnd:@"🔴 The webserver is already offline."];
                        return;
                    }
                    
                    [server halt];
                    [console progressEnd:@"ℹ️  The server is now offline. Type 'start' to bring it back online."];
                    return;
                }
                
                if([command isEqualToString:@"exit"]) {
                    [console progress:@"⏳ Terminating..."];
                    [server halt];
                    continueREPL = false;
                    return;
                }
                
                [console print:@"%@ %@", @"🔴 Unrecognized command:", command];
            })(command);
        }
    
        [console progressEnd:@"👋 Goodbye!"];
        [console destroy];
    }
    
    return 0;
    
}
