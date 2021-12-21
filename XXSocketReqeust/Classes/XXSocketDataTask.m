//
//  XXSocketDataTask.m
//  XXSocketRequestDemo
//
//  Created by Stellar on 17/2/20.
//

#import "XXSocketDataTask.h"
#import "NSData+XXSocketReqeust.h"
#import "http_parser.h"
#if __has_include(<CocoaAsyncSocket/GCDAsyncSocket.h>)
#import <CocoaAsyncSocket/GCDAsyncSocket.h>
#else
#import "GCDAsyncSocket.h"
#endif
#if __has_include(<AFNetworking/AFNetworking.h>)
#import <AFNetworking/AFNetworking.h>
#else
#import "AFNetworking.h"
#endif


#define XXSocketDataTaskDomain @"XXSocketDataTaskDomain"

#pragma mark -

@interface XXSocketDataTask ()<GCDAsyncSocketDelegate> {
    NSHTTPURLResponse *_response;
    http_parser *_parser;
}

@property (nullable, readwrite, copy) NSURLRequest  *request;
@property (strong, readwrite) NSMutableData * body;

@property (strong, nonatomic) GCDAsyncSocket * asyncSocket;
@property (strong, nonatomic) NSMutableData * responseData;

@property (assign) BOOL isNewParserWithBody;
@property (assign) BOOL isNewParserWithHeader;
@property (assign) BOOL isParserSuccess;
@property (strong) NSMutableArray * allHeaderFieldInfos;

- (int) httpParserParserHeaderComplte;
- (void) completeWithError:(NSError *)error;

@end

#pragma mark -

int
body_cb (http_parser *p, const char *buf, size_t len)
{
    XXSocketDataTask * task = (__bridge XXSocketDataTask *)p->data;
    //会用多个http_parser解析，http_parser解析会回调多次，所以最后一次创建的解析器的数据才是最终的数据。
    if (task.isNewParserWithBody) {
        task.body = [NSMutableData data];
        task.isNewParserWithBody = NO;
    }
    [task.body appendBytes:buf length:len];
    return 0;
}

int
on_header_field_cb (http_parser *p, const char *buf, size_t len)
{
    NSData * data = [NSData dataWithBytes:buf length:len];
    NSString * field = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    XXSocketDataTask * task = (__bridge XXSocketDataTask *)p->data;
    if (task.isNewParserWithHeader) {
        task.allHeaderFieldInfos = [NSMutableArray array];
        task.isNewParserWithHeader = NO;
    }
    
    [task.allHeaderFieldInfos addObject:field];
    return 0;
}

int
on_header_value_cb (http_parser *p, const char *buf, size_t len)
{
    NSData * data = [NSData dataWithBytes:buf length:len];
    NSString * value = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    XXSocketDataTask * task = (__bridge XXSocketDataTask *)p->data;
    [task.allHeaderFieldInfos addObject:value];
    return 0;
}

int
headers_complete_cb (http_parser *p)
{
    XXSocketDataTask * task = (__bridge XXSocketDataTask *)p->data;
    return [task httpParserParserHeaderComplte];
}


int
message_complete_cb (http_parser *p)
{
    XXSocketDataTask * task = (__bridge XXSocketDataTask *)p->data;
    [task completeWithError:nil];
//    NSString * body = [[NSString alloc] initWithData:task.body encoding:NSUTF8StringEncoding];
    NSLog(@"message_complete_cb");
    return 0;
}

static http_parser_settings settings =
{
    .on_headers_complete = headers_complete_cb
    ,.on_message_complete = message_complete_cb
    ,.on_body = body_cb
    ,.on_header_value = on_header_value_cb
    ,.on_header_field = on_header_field_cb
};


@implementation XXSocketDataTask
@synthesize response = _response;

- (instancetype)initWithRequest:(NSURLRequest *)request viaInterface:(XXNetworkInterface)interface {
    self = [super init];
    if (self) {
        _request = request;
        _interface = interface;
        _taskIdentifier = [NSUUID UUID].UUIDString;
    }
    return self;
}

#pragma mark -
- (void) completeWithError:(NSError *)error {
    //避免重复回调
    if (_state == XXSocketTaskStateCompleted) {
        return;
    }
    _state = XXSocketTaskStateCompleted;

    //得到返回的body数据
    if (!error) {
        _mutableData = [_body copy];
    }

    //回调delegate
    if (_delegate && [_delegate respondsToSelector:@selector(socketTask:didCompleteWithError:)]) {
        [_delegate socketTask:self didCompleteWithError:error];
    }
    
    //完成后需要断开连接
    _asyncSocket.delegate = nil;
    [_asyncSocket disconnect];
}

/*! 成功返回0， 失败返回-1 */
- (int)httpParserParserHeaderComplte {
    NSMutableDictionary * allHeaderFields = [NSMutableDictionary dictionary];
    NSArray * allInfos = [self.allHeaderFieldInfos copy];
    if (allInfos.count < 2) {
        NSError * error = [NSError errorWithDomain:XXSocketDataTaskDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"header 解析失败"}];
        [self completeWithError:error];
        return 1;
    }
    NSUInteger index = 0;
    while (index < allInfos.count) {
        NSString * key = allInfos[index];
        NSString * value = allInfos[index + 1];
        [allHeaderFields setValue:value forKey:key];
        index += 2;
    }
    
    int statusCode = _parser->status_code;
    
    _response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL statusCode:statusCode HTTPVersion:nil headerFields:allHeaderFields];
    
    if ([_request.HTTPMethod isEqualToString:@"HEAD"]) {
        [self completeWithError:nil];
    }
    
//    NSLog(@"allHeaderFields: %@", allHeaderFields);
    return 0;
}


#pragma mark - Public method
- (void)start {
    //只能执行一次
    if (_asyncSocket) {
        return;
    }
    
    _state = XXSocketTaskStateRunning;
    
    dispatch_queue_t queue = _completeQueue ?: dispatch_get_main_queue();
    
    __weak __typeof__ (self) wself = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_request.timeoutInterval * NSEC_PER_SEC)), queue, ^{
        if (wself.state == XXSocketTaskStateRunning) {
            NSError * timeoutError = [NSError errorWithDomain:XXSocketDataTaskDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"超时了"}];
            [wself completeWithError:timeoutError];
        }
    });
    
    _asyncSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:queue];
    
    NSError *error = nil;
    uint16_t port = [self socketPortWithURL:_request.URL];
    NSString *host = _request.URL.host;
    NSString *ifaName = [self ifaNameWithType:_interface];
    BOOL flag = [_asyncSocket connectToHost:host
                                     onPort:port
                               viaInterface:ifaName
                                withTimeout:_request.timeoutInterval
                                      error:&error];
    if (!flag){
        NSLog(@"Unable to connect to due to invalid configuration: %@", error);
        [self completeWithError:error];
        return;
    }
    else{
        NSLog(@"Connecting to \"%@\" on port %hu...", host, port);
    }
    
    //https请求的支持
    if ([_request.URL.scheme isEqualToString:@"https"]) {
        NSDictionary *options = @{
                                  GCDAsyncSocketManuallyEvaluateTrust : @(YES),
                                  GCDAsyncSocketSSLPeerName : host
                                  };
        
        [_asyncSocket startTLS:options];
    }
}


- (void)cancel {
    _state = XXSocketTaskStateCanceling;
    [_asyncSocket disconnect];
    _asyncSocket = nil;
}


#pragma mark - GCDAsyncSocketDelegate
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port {
    NSData * requestData = [NSData httpRequestDataFormatWithRequest:_request];
    [_asyncSocket writeData:requestData withTimeout:-1.0 tag:0];
    
    NSData *responseTerminatorData = [@"\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding];
    [_asyncSocket readDataToData:responseTerminatorData withTimeout:-1.0 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
//    NSString *httpResponse = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
//    NSLog(@"socket:didReadData:withTag:\n%@", httpResponse);
    
    if (!_responseData) {
        _responseData = [NSMutableData data];
    }
    
    [_responseData appendData:data];
    
    //无法判断请求数据已经接收完成，只能每次收到数据都进行解析
    _isNewParserWithBody = YES;
    _isNewParserWithHeader = YES;
    _parser = malloc(sizeof(http_parser));
    http_parser_init(_parser, HTTP_RESPONSE);
    _parser->data = (__bridge void *)(self);

    size_t parsed;
    parsed = http_parser_execute(_parser, &settings, _responseData.bytes, _responseData.length);
    
    
    if (data == nil) {
        NSError * error = [NSError errorWithDomain:XXSocketDataTaskDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"didReadData 返回空数据"}];
        [self completeWithError:error];
        return;
    }
    else if (_parser->upgrade) {
        NSError * error = [NSError errorWithDomain:XXSocketDataTaskDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"数据解析到upgrade"}];
        [self completeWithError:error];
        return;
    }
    else if (parsed != _responseData.length) {
        NSError * error = [NSError errorWithDomain:XXSocketDataTaskDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"数据解析异常"}];
        [self completeWithError:error];
        return;
    }
    else {
        [_asyncSocket readDataWithTimeout:-1.0 tag:0];
    }
    
    free(_parser);
    _parser = NULL;
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    if (err && _state != XXSocketTaskStateCompleted) {
        [self completeWithError:err];
    }
    else {
        NSLog(@"socketDidDisconnect:withError: \"%@\"", err);
    }
}

- (void)socket:(GCDAsyncSocket *)sock didReceiveTrust:(SecTrustRef)trust completionHandler:(void (^)(BOOL shouldTrustPeer))completionHandler {
    dispatch_queue_t bgQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(bgQueue, ^{
        
        //由于https的证书一般是绑定域名的，当使用ip进行https访问时，证书校验会失败，所以强制返回成功，保障https请求完成。
        if ([self validIsIP:self.request.URL.host]) {
            completionHandler(YES);
            return ;
        }
        
        // This is where you would (eventually) invoke SecTrustEvaluate.
        // Presumably, if you're using manual trust evaluation, you're likely doing extra stuff here.
        // For example, allowing a specific self-signed certificate that is known to the app.
        
        SecTrustResultType result = kSecTrustResultDeny;
        OSStatus status = SecTrustEvaluate(trust, &result);
        
        if (status == noErr && (result == kSecTrustResultProceed || result == kSecTrustResultUnspecified)) {
            completionHandler(YES);
        }
        else {
            completionHandler(NO);
        }
    });
}

#pragma mark - tool

- (uint16_t)socketPortWithURL:(NSURL *)URL {
    uint16_t port = [URL.port unsignedIntValue];;
    if (port == 0) {
        if ([URL.scheme isEqualToString:@"http"]) {
            port = 80;
        }
        else if ([URL.scheme isEqualToString:@"https"]) {
            port = 443;
        }
        else {
            NSString * msg = [NSString stringWithFormat:@"错误的scheme%@ url:%@", URL.scheme, URL];
            NSError * error = [NSError errorWithDomain:XXSocketDataTaskDomain code:0 userInfo:@{NSLocalizedDescriptionKey : msg}];
            [self completeWithError:error];
            NSLog(@"%@", msg);
        }
    }
    return port;
}

- (NSString *)ifaNameWithType:(XXNetworkInterface)interface {
    if (interface == XXNetworkInterfaceWiFi) {
        return @"en0";
    } else if (interface == XXNetworkInterfaceCellular) {
        return @"pdp_ip0";
    } else {
        NSString * msg = [NSString stringWithFormat:@"错误的XXNetworkInterface类型：%@", @(interface)];
        NSError * error = [NSError errorWithDomain:XXSocketDataTaskDomain code:0 userInfo:@{NSLocalizedDescriptionKey : msg}];
        [self completeWithError:error];
        NSLog(@"%@", msg);
        return nil;
    }
}

- (BOOL)validIsIP:(NSString *)str {
    if (!str) {
        return NO;
    }
    
    if ([str containsString:@":"]) {
        return [self validIPV4Address:str];
    } else if ([str containsString:@"."]) {
        return [self validIPV6Address:str];
    }
    return NO;
}

- (BOOL)validIPV4Address:(NSString *)ipStr {
    NSString *ipv4Chunk = @"([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])";
    NSString *regexStr = [NSString stringWithFormat:@"^(%@\\.){3}%@$", ipv4Chunk, ipv4Chunk];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regexStr];
    return [predicate evaluateWithObject:ipStr];
}

- (BOOL)validIPV6Address:(NSString *)ipStr {
    NSString *ipv6Chunk = @"([0-9a-fA-F]{1,4})";
    NSString *regexStr = [NSString stringWithFormat:@"^(%@\\:){7}%@$", ipv6Chunk, ipv6Chunk];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regexStr];
    return [predicate evaluateWithObject:ipStr];
}

@end
