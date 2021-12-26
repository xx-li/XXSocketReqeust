//
//  XXViewController.m
//  XXSocketReqeust
//
//  Created by lixinxing on 12/19/2021.
//  Copyright (c) 2021 lixinxing. All rights reserved.
//

#import "XXViewController.h"
@import XXSocketReqeust;

@interface XXViewController ()

@property(strong, nonatomic) XXSocketRequestManager * manager;

@end

@implementation XXViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    /// 实际使用中，一般使用单例来持有XXSocketRequestManager实例
    _manager = [[XXSocketRequestManager alloc] init];
    NSURL *url = [NSURL URLWithString:@"https://www.baidu.com"];
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url];
    XXSocketDataTask *task = [_manager dataTaskWithRequest:request viaInterface:XXNetworkInterfaceWiFi completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        NSLog(@"error is :%@\n response is %@", error, response);
        NSLog(@"responseObject: %@", [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding]);
    }];
    [task start];
    
    
}

@end
