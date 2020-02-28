//
//  ReqRes.m
//  WebServer
//
//  Created by Sam Mearns on 2/28/20.
//  Copyright © 2020 Apollo Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

#import "ReqRes.h"

@implementation Request : NSObject

-(instancetype)init: (struct request_data*) initialData {
    self = [super init];
    if (self) {
        NSString *method = [initialData->method uppercaseString];
        Method methodEnum = @{
            @"GET": GET,
            @"POST": POST,
            @"PUT": PUT,
            @"PATCH": PATCH,
            @"DELETE": DELETE
        }[method];
        
        _method = methodEnum;
        _path = initialData->path;
        _httpVersion = initialData->httpVersion;
        
        NSArray *headerLines = initialData->headers;
        NSMutableDictionary<NSString *, NSString *> *headers = [[NSMutableDictionary alloc] init];
        
        for (NSString *headerLine in headerLines) {
            NSRange valueRange = [headerLine rangeOfString:@": "];
            
            if(valueRange.location == NSNotFound) continue;
            
            NSString *key = [[headerLine substringToIndex:valueRange.location] lowercaseString];
            NSString *value = [headerLine substringFromIndex:(valueRange.location + 2)];
            
            [headers setValue:value forKey:key];
        }
        
        _headers = headers;
    }
    
    return self;
}

-(NSString*)header: (NSString*) name {
    return [_headers valueForKey:[name lowercaseString]];
}

@end

@implementation Response : NSObject
- (instancetype)init {
    self = [super init];
    if (self) {
        status = @200;
        headers = [[NSMutableDictionary alloc] init];
        output = [NSMutableString stringWithString:@""];
    }
    
    return self;
}

-(Response*) header: (NSString*) header value:(NSString*) value {
    [self setHeader:header value:value];
    return self;
}

-(void)setHeader: (NSString*) header value:(NSString*) value {
    [headers setValue:value forKey:[header lowercaseString]];
}

-(Response*)status: (NSNumber*) status {
    self->status = status;
    return self;
}

-(Response*)prepend: (NSString*) data {
    [output insertString:data atIndex:0];
    return self;
}

-(Response*)append: (NSString*) data {
    [output appendString:data];
    return self;
}

-(void)write: (NSString*) data {
    [output setString:data];
}
@end
