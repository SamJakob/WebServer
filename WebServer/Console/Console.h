//
//  Console.h
//  WebServer
//
//  Created by Sam Mearns on 2/29/20.
//  Copyright © 2020 Apollo Software. All rights reserved.
//

#ifndef Console_h
#define Console_h

#include <locale.h>
#include <curses.h>
#include <term.h>
#include <unistd.h>

#import "Server.h"

@interface Console : NSObject {
@private
    int _statusLine;
    int _promptLine;
}

-(instancetype) init:(NSString*) consoleName statusLine:(int) statusLine promptLine:(int) promptLine;
-(void) renderStatus:(Server*) server;
-(void) log:(NSString*) format, ...;
-(void) progress:(NSString*) format, ...;
-(void) progressEnd:(NSString*) format, ...;
-(void) print:(NSString*) format, ...;
-(NSString*) prompt:(NSString*) prompt;
-(void) destroy;

-(void) _clear;
@end

#endif /* Console_h */
