//
//  XXSocketReqeustTests.m
//  XXSocketReqeustTests
//
//  Created by lixinxing on 12/19/2021.
//  Copyright (c) 2021 lixinxing. All rights reserved.
//

@import XCTest;



@interface Tests : XCTestCase

@end

@implementation Tests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample
{
    XCTAssert([self validIsIP:@"172.16.254.1"]);
    XCTAssert([self validIsIP:@"192.168.251.111"]);
    XCTAssert([self validIsIP:@"1050:0000:0000:0000:0005:0600:300c:326b"]);
    XCTAssert([self validIsIP:@"192.168.251.1111"] == false);
    XCTAssert([self validIsIP:@"www.baidu.com"] == false);
}


- (BOOL)validIsIP:(NSString *)str
{
    if (!str) {
        return NO;
    }
    
    if ([str containsString:@"."]) {
        return [self validIPV4Address:str];
    } else if ([str containsString:@":"]) {
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

