//
//  Console.m
//  WebServer
//
//  Created by Sam Mearns on 2/29/20.
//  Copyright © 2020 Apollo Software. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "Console.h"

@implementation Console : NSObject
-(instancetype) init:(NSString*) consoleName statusLine:(int) statusLine promptLine:(int) promptLine {
    self = [super init];
    if (self) {
        self->_statusLine = statusLine;
        self->_promptLine = promptLine;
        
        setlocale(LC_ALL, "");
        initscr();
    }
    
    return self;
}

-(void) renderStatus:(Server*) server {
    
    // Save current position.
    int y, x;
    getyx(stdscr, y, x);
    
    // Move to status line.
    move(self->_statusLine, 0);
    clrtoeol();
    
    // TODO: Render status line.
    attron(A_BOLD);
    printw("Status: ");
    attroff(A_BOLD);
    addstr((server.listening ? "Online" : "Offline"));
    
    // Return to previous position.
    move(y, x);
    
}

-(void) log:(NSString *) format, ... {
    va_list args;
    va_start(args,format);
    NSString *s=[[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    addstr([s UTF8String]);
}

-(void) progress:(NSString*) format, ... {
    va_list args;
    va_start(args,format);
    NSString *s = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    [self _clear];
    
    const char* output = [[NSString stringWithFormat:@"%@", s] UTF8String];
    addstr(output);
}

-(void) progressEnd:(NSString*) format, ... {
    va_list args;
    va_start(args,format);
    NSString *s=[[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    [self _clear];
    
    addstr([s UTF8String]);
    addstr("\n");
}

-(void) print:(NSString*) format, ... {
    va_list args;
    va_start(args,format);
    NSString *s=[[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    addstr([s UTF8String]);
    addstr("\n");
}

-(NSString*) prompt:(NSString*) prompt {
    move(self->_promptLine, 0);
    [self _clear];
    
    const char* output = [[NSString stringWithFormat:@"%@", prompt] UTF8String];
    addstr(output);
    
    char data[80];
    getstr(data);
    
    return [NSString stringWithUTF8String:data];
}

/// Helper method to clear the current console line in preperation for a progress call to be made.
-(void) _clear {
    
    // Save current position.
    int y, x;
    getyx(stdscr, y, x);
    
    // Move to the start of the current line and clear it.
    move(y, 0);
    clrtoeol();
    
}

-(void) destroy {
    endwin();
}

@end
