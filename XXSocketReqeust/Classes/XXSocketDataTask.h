//
//  XXSocketDataTask.h
//  XXSocketRequestDemo
//
//  Created by Stellar on 17/2/20.
//

#import <Foundation/Foundation.h>
@class XXSocketDataTask;

NS_ASSUME_NONNULL_BEGIN

/**
 网络请求的通道
 
 - XXNetworkInterfaceCellular: 通过蜂窝网络进行请求
 - XXNetworkInterfaceWiFi: 通过WiFi进行请求
 */
typedef NS_ENUM(NSInteger, XXNetworkInterface) {
    XXNetworkInterfaceCellular = 0,
    XXNetworkInterfaceWiFi,
};

/// Socket请求任务状态
typedef NS_ENUM(NSInteger, XXSocketTaskState) {
    /// 初始化
    XXSocketTaskStateInit = 0,
    /// 请求中
    XXSocketTaskStateRunning,
    /// 任务被取消
    XXSocketTaskStateCanceling,
    /// 任务已完成
    XXSocketTaskStateCompleted,
};

@protocol XXSocketDataTaskDelegate <NSObject>

- (void)socketTask:(XXSocketDataTask *)task didCompleteWithError:(nullable NSError *)error;

@end

/// 对Http请求的Socket封装。
///
/// 内部会对NSURLRequest进行解析，组装成符合http协议格式的二进制数据。
/// 通过CocoaAsyncSocket框架，在socket层绑定特定网卡（蜂窝网络或Wi-Fi）
/// 将http request格式的二进制数据发送至服务器。
/// 收到服务端返回的二进制数据后，使用node.js的http解析（c语言）框架http_parser解析出http response。
@interface XXSocketDataTask : NSObject

@property (weak, nonatomic) id<XXSocketDataTaskDelegate> delegate;

@property (readonly, copy) NSURLRequest  *request;

/// 请求绑定的网卡
@property (readonly) XXNetworkInterface interface;

@property (readonly) XXSocketTaskState state;
/// 请求任务的唯一标识符
@property (strong, readonly) NSString * taskIdentifier;

/// 请求完成后的response
@property (nullable, readonly, copy) NSHTTPURLResponse *response;
/// 请求完成后获取到的Data
@property (nullable, strong, readonly) NSData * mutableData;

///  Callback complete  delegate at this queue, if NULL, use main_queue.
@property (nonatomic, strong, nullable) dispatch_queue_t completeQueue;

/// 初始化方法
- (instancetype)initWithRequest:(NSURLRequest *)request
                   viaInterface:(XXNetworkInterface)interface;

/// 开始请求
/// 一个请求只能有效start一次
- (void)start;

/// 取消请求。
- (void)cancel;

@end

NS_ASSUME_NONNULL_END

