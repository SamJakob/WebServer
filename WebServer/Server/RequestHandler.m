//
//  RequestHandler.m
//  WebServer
//
//  Created by Sam Mearns on 2/28/20.
//  Copyright © 2020 Apollo Software. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RequestHandler.h"

@implementation RequestHandler : NSObject

@synthesize method = _method;
@synthesize path = _path;

-(instancetype) init:(Method) method forPath:(NSString*) path andWithBlock:(RequestBlock) block {
    if(self = [super init]){
        // Initialize self.
        _method = method;
        _path = path;
        _block = block;
    }
    
    return self;
}

-(bool) shouldExecuteFor:(Request*) request {
    return self.method == request.method && [self.path isEqual:request.path];
}

-(void) execute:(Request*) request response:(Response*) response {
    self->_block(request, response);
}

@end
