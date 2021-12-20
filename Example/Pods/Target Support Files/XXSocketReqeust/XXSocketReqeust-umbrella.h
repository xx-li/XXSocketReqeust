#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "http_parser.h"
#import "NSData+XXSocketReqeust.h"
#import "XXSocketDataTask.h"
#import "XXSocketRequestManager.h"

FOUNDATION_EXPORT double XXSocketReqeustVersionNumber;
FOUNDATION_EXPORT const unsigned char XXSocketReqeustVersionString[];

