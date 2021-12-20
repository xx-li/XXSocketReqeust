//
//  XXSocketRequestManager.m
//  XXSocketRequestDemo
//
//  Created by Stellar on 17/2/20.
//

#import "XXSocketRequestManager.h"
#import "XXSocketDataTask.h"
#if __has_include(<AFNetworking/AFNetworking.h>)
#import <AFNetworking/AFNetworking.h>
#else
#import "AFNetworking.h"
#endif

static dispatch_queue_t url_session_manager_processing_queue() {
    static dispatch_queue_t xx_url_session_manager_processing_queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        xx_url_session_manager_processing_queue = dispatch_queue_create("com.xxsocketrequest.manager.processing", DISPATCH_QUEUE_CONCURRENT);
    });
    
    return xx_url_session_manager_processing_queue;
}

static dispatch_group_t url_session_manager_completion_group() {
    static dispatch_group_t xx_url_session_manager_completion_group;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        xx_url_session_manager_completion_group = dispatch_group_create();
    });
    
    return xx_url_session_manager_completion_group;
}


typedef  void (^XXSocketDataTaskCompletionHandler)(NSURLResponse *response, id _Nullable responseObject,  NSError * _Nullable error) ;


@interface XXSocketRequestManager ()<XXSocketDataTaskDelegate>

@property (nonatomic, strong) AFHTTPRequestSerializer <AFURLRequestSerialization> * requestSerializer;
@property (nonatomic, strong) AFHTTPResponseSerializer <AFURLResponseSerialization> * responseSerializer;
@property (readwrite, nonatomic, strong) NSMutableDictionary *mutableTaskDelegatesKeyedByTaskIdentifier;
@property (readwrite, nonatomic, strong) NSLock *lock;

- (void)removeDelegateForTask:(XXSocketDataTask *)task;

@end


@interface XXSocketManagerTaskDelegate : NSObject <XXSocketDataTaskDelegate>
@property (strong, nonatomic) XXSocketDataTask * task;
@property (nonatomic, weak) XXSocketRequestManager *manager;
@property (nonatomic, copy) XXSocketDataTaskCompletionHandler completionHandler;
@end

@implementation XXSocketManagerTaskDelegate

- (void)setTask:(XXSocketDataTask *)task {
    if (task == _task) {
        return;
    }
    _task = task;
    _task.delegate = self;
}

- (void)socketTask:(XXSocketDataTask *)task didCompleteWithError:(nullable NSError *)error
{
    __strong XXSocketRequestManager *manager = self.manager;
    __block id responseObject = nil;
    dispatch_queue_t queue = task.completeQueue ?: dispatch_get_main_queue();
    if (error) {
        dispatch_group_async(url_session_manager_completion_group(), queue, ^{
            if (self.completionHandler) {
                self.completionHandler(task.response, responseObject, error);
            }
        });
    }
    else {
        dispatch_async(url_session_manager_processing_queue(), ^{
            NSError *serializationError = nil;
            responseObject = [manager.responseSerializer responseObjectForResponse:task.response data:task.mutableData error:&serializationError];
            
            dispatch_group_async(url_session_manager_completion_group(), queue, ^{
                if (self.completionHandler) {
                    self.completionHandler(task.response, responseObject, serializationError);
                }
            });
        });
    }
    
    [manager performSelector:@selector(removeDelegateForTask:) withObject:task];
}

@end


@implementation XXSocketRequestManager

- (instancetype)init
{
    self = [super init];
    if (self) {
        _requestSerializer = [AFHTTPRequestSerializer serializer];
        _responseSerializer = [AFHTTPResponseSerializer serializer];
        self.mutableTaskDelegatesKeyedByTaskIdentifier = [[NSMutableDictionary alloc] init];
        self.lock = [[NSLock alloc] init];
        self.lock.name = @"XXSocketRequestManagerLockName";
    }
    return self;
}

- (nullable XXSocketDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                                        viaInterface:(XXNetworkInterface)interface
                                   completionHandler:(nullable XXSocketDataTaskCompletionHandler)completionHandler
{
    XXSocketDataTask *task = [[XXSocketDataTask alloc] initWithRequest:request viaInterface:interface];
    [self addDelegateForDataTask:task completionHandler:completionHandler];
    
    return task;
}

- (void)addDelegateForDataTask:(XXSocketDataTask *)dataTask
             completionHandler:(void (^)(NSURLResponse *response, id responseObject, NSError *error))completionHandler
{
    XXSocketManagerTaskDelegate *delegate = [[XXSocketManagerTaskDelegate alloc] init];
    delegate.task = dataTask;
    delegate.manager = self;
    delegate.completionHandler = completionHandler;
    
    [self setDelegate:delegate forTask:dataTask];
}

#pragma mark -
- (XXSocketManagerTaskDelegate *)delegateForTask:(XXSocketDataTask *)task {
    NSParameterAssert(task);
    
    XXSocketManagerTaskDelegate *delegate = nil;
    [self.lock lock];
    delegate = self.mutableTaskDelegatesKeyedByTaskIdentifier[task.taskIdentifier];
    [self.lock unlock];
    
    return delegate;
}

- (void)setDelegate:(XXSocketManagerTaskDelegate *)delegate
            forTask:(XXSocketDataTask *)task
{
    NSParameterAssert(task);
    NSParameterAssert(delegate);
    
    [self.lock lock];
    self.mutableTaskDelegatesKeyedByTaskIdentifier[task.taskIdentifier] = delegate;
    [self.lock unlock];
}

#pragma mark -
- (void)removeDelegateForTask:(XXSocketDataTask *)task {
    NSParameterAssert(task);
    [self.lock lock];
    [self.mutableTaskDelegatesKeyedByTaskIdentifier removeObjectForKey:task.taskIdentifier];
    [self.lock unlock];
}

#pragma mark -
//此方法无实际用途。仅用于避免编译时出现delegate警告
- (void)socketTask:(XXSocketDataTask *)task didCompleteWithError:(nullable NSError *)error {}

@end

