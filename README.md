# XXSocketReqeust

通过使用`socket`绑定特定网卡，将http请求解析成符合`HTTP`协议的字符串，使用socket绑定的网卡进行收发，达到无视当前路由，强制通过`蜂窝网络`或`WiFi`进行`HTTP`请求的效果。
主要适用于连接到无法访问网络的WiFi，强制通过蜂窝网络进行`HTTP`请求的场景。

## 注意
- `NSURLRequest`转换为HTTP协议数据的逻辑可以在`NSData+XXSocketReqeust.m`中看到，只提供对HTTP协议的`GET`及`POST`请求的部分支持。
- 不支持`HTTP`协议的缓存功能

## Example

```objective-c
@import XXSocketReqeust;

@interface XXViewController ()
@property(strong, nonatomic) XXSocketRequestManager * manager;
@end

@implementation XXViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    /// 实际使用中，一般使用单例来持有XXSocketRequestManager实例
    _manager = [[XXSocketRequestManager alloc] init];
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://www.baidu.com"]];
    XXSocketDataTask *task = [_manager dataTaskWithRequest:request viaInterface:XXNetworkInterfaceCellular completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        NSLog(@"error is :%@\n response is %@", error, response);
        NSLog(@"responseObject: %@", [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding]);
    }];
    [task start];
}

@end
```

## Requirements
依赖第三方框架`AFNetworking`和`CocoaAsyncSocket`

## Installation

XXSocketReqeust is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'XXSocketReqeust'
```

## Author

lixinxing, x@devlxx.com

## TODO
iOS系统中肯定存在`NSURLRequest`转换为`HTTP`协议数据的功能，但是未找到这部分的内容，待有时间逆向分析，看能否提供对`HTTP`协议的完整支持。
如果您有方案或者思路，欢迎提交`issue`

## License

XXSocketReqeust is available under the MIT license. See the LICENSE file for more info.
