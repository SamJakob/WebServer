//
//  RequestHandler.h
//  WebServer
//
//  Created by Sam Mearns on 2/28/20.
//  Copyright © 2020 Apollo Software. All rights reserved.
//

#import "ReqRes.h"

#ifndef RequestHandler_h
#define RequestHandler_h

typedef void (^RequestBlock)(Request* request, Response* response);

@interface RequestHandler : NSObject {
@private
    Method _method;
    NSString* _path;
    RequestBlock _block;
}

/// The method criteria for the handler.
@property (readonly) Method method;
/// The path criteria for the handler.
@property (readonly) NSString* path;
/// The handler for the request.
@property (readonly) RequestBlock block;

-(instancetype) init:(Method) method forPath:(NSString*) path andWithBlock:(RequestBlock) block;
-(bool) shouldExecuteFor:(Request*) request;
-(void) execute:(Request*) request response:(Response*) response;
@end

#endif /* RequestHandler_h */
