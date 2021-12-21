//
//  NSData+XXSocketReqeust.m
//  XXSocketReqeust
//
//  Created by Stellar on 2021/12/19.
//

#import "NSData+XXSocketReqeust.h"

@implementation NSData (XXSocketReqeust)

+ (NSData *)httpRequestDataFormatWithRequest:(NSURLRequest *)request {
    NSMutableString * requestStrFrmt = [NSMutableString string];
    NSURL * url = request.URL;
    
    NSString *requestURI = url.path;
    
    //状态行
    if ([request.HTTPMethod isEqualToString:@"POST"]) {
        if (!url.path || url.path.length == 0) {
            requestURI = @"/";
        }
    }
    else if ([request.HTTPMethod isEqualToString:@"GET"] || [request.HTTPMethod isEqualToString:@"HEAD"]) {
        if ((url.path && url.path.length > 0)  && (url.query && url.query.length > 0)) {
            requestURI = [NSString stringWithFormat:@"%@?%@", url.path, url.query];
        }
        else if (url.path && url.path.length > 0) {
            requestURI = url.path;
        }
        else if (url.query && url.query.length > 0) {
            requestURI = url.query;
        }
        else {
            requestURI = @"/";
        }
    }
    
    //Host一定需要
    [requestStrFrmt appendFormat:@"%@ %@ HTTP/1.1\r\n", request.HTTPMethod, requestURI];
    if ([request.allHTTPHeaderFields objectForKey:@"Host"] == nil) {
        [requestStrFrmt appendFormat:@"Host: %@\r\n", url.host];
    }
    
    //HTTPHeaderFields
    for (NSString * key in request.allHTTPHeaderFields.allKeys) {
        [requestStrFrmt appendFormat:@"%@: %@\r\n", key, request.allHTTPHeaderFields[key]];
    }
    
    //TODO:支持上传二进制功能
    //http body
    if ([request.HTTPMethod isEqualToString:@"POST"] && request.HTTPBody) {
        [requestStrFrmt appendFormat:@"Content-Length: %@\r\n", @(request.HTTPBody.length)];
        //request header 以两个CRLF结束
        [requestStrFrmt appendString:@"\r\n"];
        NSMutableData * requestData = [NSMutableData dataWithData:[requestStrFrmt dataUsingEncoding:NSUTF8StringEncoding]];
        [requestData appendData:request.HTTPBody];
        return requestData;
    } else {
        //request header 以两个CRLF结束
        [requestStrFrmt appendString:@"\r\n"];
        return [NSMutableData dataWithData:[requestStrFrmt dataUsingEncoding:NSUTF8StringEncoding]];
    }
}

@end
