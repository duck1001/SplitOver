//
//  SOSettings.m
//  SplitOver
//

#import "SOSettings.h"
#import <notify.h>

static NSString *const kSOEdgeSensitivity = @"edgeSensitivity";
static NSString *const kSOSnapGap         = @"snapGap";
static NSString *const kSOCornerRadius    = @"cornerRadius";
static NSString *const kSOOpacity         = @"windowOpacity";

@interface SOSettings () {
    int _notifyToken;
}
@property (nonatomic, strong) NSDictionary *values;
@property (nonatomic, strong) NSMutableSet<NSString *> *scaleModeCache;
@end

@implementation SOSettings

+ (instancetype)shared {
    static SOSettings *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init {
    if ((self = [super init])) {
        _scaleModeCache = [NSMutableSet new];
        [self reload];
    }
    return self;
}

- (void)reload {
    CFPreferencesAppSynchronize((__bridge CFStringRef)SO_PREFS_DOMAIN);
    CFArrayRef keys = CFPreferencesCopyKeyList((__bridge CFStringRef)SO_PREFS_DOMAIN,
                                               kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    if (keys) {
        CFDictionaryRef cf = CFPreferencesCopyMultiple(keys, (__bridge CFStringRef)SO_PREFS_DOMAIN,
                                                       kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
        if (cf) {
            dict = [(__bridge NSDictionary *)cf mutableCopy];
            CFRelease(cf);
        }
        CFRelease(keys);
    }
    self.values = dict;

    [self.scaleModeCache removeAllObjects];
    for (id bid in dict[@"scaleApps"] ?: @[])
        if ([bid isKindOfClass:[NSString class]]) [self.scaleModeCache addObject:bid];
}

- (void)observeChanges {
    if (_notifyToken) return;
    __weak typeof(self) weakSelf = self;
    notify_register_dispatch(SO_PREFS_CHANGED.UTF8String, &_notifyToken, dispatch_get_main_queue(), ^(int token) {
        [weakSelf reload];
        [[NSNotificationCenter defaultCenter] postNotificationName:SO_PREFS_CHANGED object:nil];
    });
}

#pragma mark - 读取

- (BOOL)boolForKey:(NSString *)key fallback:(BOOL)fallback {
    id v = self.values[key];
    return v ? [v boolValue] : fallback;
}

- (CGFloat)doubleForKey:(NSString *)key fallback:(CGFloat)fallback {
    id v = self.values[key];
    return v ? [v doubleValue] : fallback;
}

- (BOOL)enabled              { return [self boolForKey:@"enabled" fallback:YES]; }
- (BOOL)padEnabled           { return [self boolForKey:@"padEnabled" fallback:YES]; }
- (BOOL)padAutoCollapse      { return [self boolForKey:@"padAutoCollapse" fallback:YES]; }
- (BOOL)gestureEdgeSwipe     { return [self boolForKey:@"gestureEdgeSwipe" fallback:YES]; }
- (BOOL)gestureThreeFinger   { return [self boolForKey:@"gestureThreeFinger" fallback:YES]; }
- (BOOL)gestureStatusBarDoubleTap { return [self boolForKey:@"gestureStatusBarDoubleTap" fallback:NO]; }
- (BOOL)gestureHomeLongPress { return [self boolForKey:@"gestureHomeLongPress" fallback:YES]; }
- (BOOL)gestureInApps        { return [self boolForKey:@"gestureInApps" fallback:YES]; }
- (BOOL)keepAlive            { return [self boolForKey:@"keepAlive" fallback:YES]; }
- (BOOL)forceMultiwindow     { return [self boolForKey:@"forceMultiwindow" fallback:YES]; }
- (BOOL)hapticsEnabled       { return [self boolForKey:@"hapticsEnabled" fallback:YES]; }
- (BOOL)dimBackdrop          { return [self boolForKey:@"dimBackdrop" fallback:YES]; }

- (CGFloat)wheelIconSize { return MAX(40.0, MIN(72.0, [self doubleForKey:@"wheelIconSize" fallback:54.0])); }
- (CGFloat)wheelRadius   { return MAX(0.0, [self doubleForKey:@"wheelRadius" fallback:0.0]); }
- (CGFloat)snapDuration  { return MAX(0.08, MIN(0.6, [self doubleForKey:@"snapDuration" fallback:0.22])); }
- (CGFloat)floatWidth    { return MAX(0.4, MIN(1.0, [self doubleForKey:@"floatWidth" fallback:0.72])); }

- (SOPadCorner)padCorner {
    return (SOPadCorner)[self doubleForKey:@"padCorner" fallback:SOPadCornerRight];
}

- (CGFloat)edgeSensitivity { return MAX(0.0, MIN(1.0, [self doubleForKey:kSOEdgeSensitivity fallback:0.5])); }
- (CGFloat)snapGap         { return MAX(0.0, [self doubleForKey:kSOSnapGap fallback:8.0]); }
- (CGFloat)cornerRadius    { return MAX(0.0, [self doubleForKey:kSOCornerRadius fallback:14.0]); }
- (CGFloat)windowOpacity   { return MAX(0.3, MIN(1.0, [self doubleForKey:kSOOpacity fallback:1.0])); }

- (BOOL)scaleModeForBundleID:(NSString *)bundleID {
    return bundleID && [self.scaleModeCache containsObject:bundleID];
}

- (void)setScaleMode:(BOOL)on forBundleID:(NSString *)bundleID {
    if (!bundleID) return;
    NSMutableArray *apps = [NSMutableArray arrayWithArray:self.values[@"scaleApps"] ?: @[]];
    if (on) { if (![apps containsObject:bundleID]) [apps addObject:bundleID]; }
    else    { [apps removeObject:bundleID]; }

    CFPreferencesSetAppValue(CFSTR("scaleApps"), (__bridge CFArrayRef)apps,
                             (__bridge CFStringRef)SO_PREFS_DOMAIN);
    CFPreferencesAppSynchronize((__bridge CFStringRef)SO_PREFS_DOMAIN);
    [self reload];
}

- (CGPoint)padCenter {
    CGFloat x = [self doubleForKey:@"padX" fallback:-1];
    CGFloat y = [self doubleForKey:@"padY" fallback:-1];
    return CGPointMake(x, y);
}

- (void)setPadCenter:(CGPoint)center {
    CFPreferencesSetAppValue(CFSTR("padX"), (__bridge CFNumberRef)@(center.x), (__bridge CFStringRef)SO_PREFS_DOMAIN);
    CFPreferencesSetAppValue(CFSTR("padY"), (__bridge CFNumberRef)@(center.y), (__bridge CFStringRef)SO_PREFS_DOMAIN);
    CFPreferencesAppSynchronize((__bridge CFStringRef)SO_PREFS_DOMAIN);
    NSMutableDictionary *d = [self.values mutableCopy];
    d[@"padX"] = @(center.x);
    d[@"padY"] = @(center.y);
    self.values = d;
}

@end
