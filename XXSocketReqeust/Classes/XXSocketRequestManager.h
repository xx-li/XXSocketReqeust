//
//  XXSocketRequestManager.h
//  XXSocketRequestDemo
//
//  Created by Stellar on 17/2/20.
//

#import <Foundation/Foundation.h>
#import "XXSocketDataTask.h"


NS_ASSUME_NONNULL_BEGIN

/// XXSocketDataTask请求完成回调的封装
///
/// @param response HTTP请求的response，如果请求失败，则为nil
/// @param responseObject 使用AFHTTPResponseSerializer格式化响应数据后的信息
/// @param error  请求错误信息，无错误时为nil
typedef void (^XXSocketDataTaskCompletionHandler)(NSURLResponse *_Nullable response, id _Nullable responseObject, NSError * _Nullable error);


/// 对XXSocketDataTask的封装。提供便捷的block调用方式。
@interface XXSocketRequestManager : NSObject


/// XXSocketDataTask使用block回调都调用方式
/// @param request HTTP请求
/// @param interface 绑定的特定网卡。 蜂窝网络或者Wi-Fi
/// @param completionHandler 请求完成的回调
- (nullable XXSocketDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                                        viaInterface:(XXNetworkInterface)interface
                                   completionHandler:(nullable XXSocketDataTaskCompletionHandler)completionHandler;

@end

NS_ASSUME_NONNULL_END

