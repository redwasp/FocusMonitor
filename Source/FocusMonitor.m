//
//  FocusMonitor.m
//
//  Created by Pavlo Liashenko on 27.02.2023.
//

#import "FocusMonitor.h"
#include <notify.h>

#define Error(number, format, ...) \
[[self class] errorWithDescription: [NSString stringWithFormat:format,  ## __VA_ARGS__] code: number]

NSString * const FocusStateDidUpdatedNotificationName = @"FocusStateDidUpdatedNotification";
NSString * const FocusStateKey = @"state";
NSString * const FocusMonitorErrorDomain = @"FocusMonitor";
NSString * const FocusInternalNotificationNameFormat = @"user.uid.%d.com.apple.notificationcenter.dnd";

@interface FocusMonitor()

@property (nonatomic, assign, getter = isEnabled) BOOL enabled;
@property (nonatomic, copy) FocusMonitorStateUpdateCallback callback;
@property (nonatomic, copy) FocusMonitorErrorCallback errorCallback;

@end

@implementation FocusMonitor

static FocusMonitor *shared = nil;
static NSString * focusStateNotificationName = nil;
static int checkToken = 0;
static int dispatchToken = 0;

+ (BOOL)isEnabled {
    if (shared != nil) {
        return [[self shared] isEnabled];
    } else {
        return [self getFocusState];
    }
}

+ (void)start {
    [self startWithCallback:nil error:nil];
}

+ (void)startWithCallback:(nullable FocusMonitorStateUpdateCallback)callback error:(nullable FocusMonitorErrorCallback)errorCallback {
    if (shared != nil) {
        Error(AlreadyRunning, @"(Warning) Already running");
    }
    FocusMonitor *monitor = shared == nil ? [self shared] : shared;
    monitor.enabled = [self.class getFocusState];
    @synchronized([self class]) {
        monitor.callback = callback;
        monitor.errorCallback = errorCallback;
    }
    if (dispatchToken == 0) {
        [monitor setupNotification];
    }
    if (callback != nil) {
        callback(monitor.enabled);
    }
}

+ (void)stop {
    if (shared == nil) {
        Error(AlreadyStopped, @"(Warning) Already stopped");
        return;
    }
    
    FocusMonitor *monitor = [self shared];
    [monitor removeNotifications];
    monitor.callback = nil;
    monitor.errorCallback = nil;
    monitor.enabled = false;
    shared = nil;
}

+ (instancetype)shared {
    @synchronized([self class]) {
        if (shared == nil) {
            shared = [[[self class] alloc] initPrivate];
        }
        return shared;
    }
}

- (instancetype)initPrivate {
    self = [super init];
    if (self) {
    }
    return self;
}

- (instancetype)init {
    return shared;
}


+ (const char *)focusStateNotificationName {
    if (focusStateNotificationName == nil) {
        uid_t userID = 0;
        userID = geteuid();
        if (userID == 0) {
            userID = getuid();
        }
        if (userID == 0) {
            Error(GetUserIDFiled, @"Get user ID filed");
            return nil;
        }
        focusStateNotificationName = [NSString stringWithFormat:FocusInternalNotificationNameFormat, userID];
    }
    return [focusStateNotificationName cStringUsingEncoding: NSUTF8StringEncoding];
}

+ (BOOL)getFocusState {
    if (checkToken == 0) {
        int result = notify_register_check(self.focusStateNotificationName, &checkToken);
        if (result != 0 || checkToken == 0 || checkToken == -1) {
            Error(GetTokenFailed, @"Get token failed (%X)", result);
            checkToken = 0;
            return false;
        }
    }
    
    uint64_t state = 0;
    int result = notify_get_state(checkToken, &state);
    if (result != 0) {
        Error(GetStateFailed, @"Get state failed (%X)", result);
    }
    return state == 1;
}

- (void)setupNotification {
    if (dispatchToken != 0) {
        Error(NotificationSetupFiled, @"(Warning) Notification already configured");
        return;
    }
    uint32_t result = notify_register_dispatch(self.class.focusStateNotificationName, &dispatchToken, dispatch_get_main_queue(), ^(int token) {
        uint64_t state = 0;
        uint32_t result = notify_get_state(token, &state);
        if (result != 0) {
            Error(GetStateFailed, @"Get state failed (%X)", result);
            return;
        }
        self.enabled = state;
    });
    if (result != 0) {
        Error(NotificationSetupFiled, @"Setup notication failed (%X)", result);
        dispatchToken = 0;
    }
}

- (void)removeNotifications {
    uint32_t result = 0;
    
    result = notify_cancel(dispatchToken);
    if (result != 0) {
        Error(ReleaseNoticationFailed, @"Release dispatch token failed (%X)", result);
    }
    dispatchToken = 0;
    
    result = notify_cancel(checkToken);
    if (result != 0) {
        Error(ReleaseNoticationFailed, @"Release check token failed (%X)", result);
    }
    checkToken = 0;
}


- (void)setEnabled:(BOOL)enabled {
    if (_enabled != enabled) {
        _enabled = enabled;
        [[NSNotificationCenter defaultCenter] postNotificationName: FocusStateDidUpdatedNotificationName
                                                            object: self
                                                          userInfo: @{FocusStateKey: @(enabled)}];
        if (self.callback != nil) {
            self.callback(enabled);
        }
    }
}


+ (void)errorWithDescription:(NSString *)description code:(FocusMonitorErrorCode)code {
    if (shared && shared.errorCallback) {
        NSError *error = [NSError errorWithDomain: FocusMonitorErrorDomain
                                             code: code
                                         userInfo: @{NSLocalizedDescriptionKey: description}];
        shared.errorCallback(error);
    }
    
#if DEBUG
    NSLog(@"[FocusMonitor][Error] %@ (%lX)", description, (long)code);
#endif
    
}


@end
