//
//  FocusMonitor.h
//
//  Created by Pavlo Liashenko on 27.02.2023.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const FocusStateDidUpdatedNotificationName;
extern NSString * const FocusStateKey;

typedef void (^FocusMonitorStateUpdateCallback)(BOOL state);
typedef void (^FocusMonitorErrorCallback)(NSError *error);

extern NSString * const FocusMonitorErrorDomain;

typedef enum : NSUInteger {
    AlreadyRunning = 1,
    AlreadyStopped = 2,
    GetUserIDFiled = 3,
    GetTokenFailed = 4,
    GetStateFailed = 5,
    NotificationSetupFiled = 6,
    ReleaseNoticationFailed = 7
} FocusMonitorErrorCode;

@interface FocusMonitor: NSObject

+ (BOOL)isEnabled;
+ (void)start;
+ (void)stop;

+ (void)startWithCallback:(nullable FocusMonitorStateUpdateCallback)callback error:(nullable FocusMonitorErrorCallback)errorCallback;

- (instancetype)init UNAVAILABLE_ATTRIBUTE;
+ (instancetype)new UNAVAILABLE_ATTRIBUTE;

@end

NS_ASSUME_NONNULL_END
