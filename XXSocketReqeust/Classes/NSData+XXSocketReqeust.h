//
//  NSData+XXSocketReqeust.h
//  XXSocketReqeust
//
//  Created by Stellar on 2021/12/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSData (XXSocketReqeust)

/// 将基于http协议的NSURLRequest转换为符合http协议的request字节流数据。
/// @param request http请求的request
/// @note 仅支持常规的GET和POST请求。 不支持HTTP协议的缓存功能。
+ (NSData *)httpRequestDataFormatWithRequest:(NSURLRequest *)request;

@end

NS_ASSUME_NONNULL_END
