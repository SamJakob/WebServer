//
//  ReqRes.h
//  WebServer
//
//  Created by Sam Mearns on 2/28/20.
//  Copyright © 2020 Apollo Software. All rights reserved.
//

#ifndef ReqRes_h
#define ReqRes_h

/**
 * @enum Method
 * @abstract Used to represent HTTP methods for a request.
 *
 * @constant GET read operations
 * @constant POST create operations
 * @constant PUT update/replace operations
 * @constant PATCH update/modify operations
 * @constant DELETE delete operations
 *
 * @discussion Only the most common verbs (specifically those representing CRUD operations)
 * have been implemented.
*/
typedef NSString* Method NS_STRING_ENUM;
static Method const GET = @"GET";
static Method const POST = @"POST";
static Method const PUT = @"PUT";
static Method const PATCH = @"PATCH";
static Method const DELETE = @"DELETE";

/*!
 * @struct request_data
 * @abstract Used to pass initial request data to a request object.
 *
 * @field method The HTTP method used to make the request.
 * @field path The path the request was made to.
 * @field httpVersion The HTTP version used to make the request.
 *
 * @discussion This is only used to pass the initial data used for the request, after this has
 * been done, the Request class should be used as it has additional methods to make using
 * request data much easier - such as methods to get header information.
 *
 * @see Request
*/
struct request_data {
    NSString *method;
    NSString *path;
    NSString *httpVersion;
    NSArray *headers;
};

/**
 * @class Request
 * @abstract The Request class allows for getting data from an HTTP request.
 */
@interface Request : NSObject {
@private
    Method _method;
    NSString *_path;
    NSString *_httpVersion;
    NSDictionary *_headers;
}

/// The HTTP method.
@property (readonly) Method method;
/// The path component of the URL that is being accessed.
@property (readonly) NSString *path;
/// The HTTP version that was used in the request.
@property (readonly) NSString *httpVersion;

-(instancetype)init: (struct request_data*) initialData;
/// Returns a header by name.
-(NSString*)header: (NSString*) name;
@end

@interface Response : NSObject {
@public
    NSNumber *status;
    NSMutableDictionary *headers;
    NSMutableString *output;
}

- (instancetype)init;
-(Response*)header: (NSString*) header value:(NSString*) value;
-(void)setHeader: (NSString*) header value:(NSString*) value;
-(Response*)status: (NSNumber*) status;
-(Response*)prepend: (NSString*) data;
-(Response*)append: (NSString*) data;
-(void)write: (NSString*) data;
@end

#endif /* ReqRes_h */
