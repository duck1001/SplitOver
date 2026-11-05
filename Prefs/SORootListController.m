//
//  SORootListController.m
//  SplitOverPrefs
//

#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <notify.h>

@interface SORootListController : PSListController
@end

@implementation SORootListController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"SplitOver";
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    [super setPreferenceValue:value specifier:specifier];

    // Preferences 进程写完立即同步，再通知 SpringBoard 里的 tweak 重读
    CFPreferencesAppSynchronize(CFSTR("com.duck1001.splitover"));
    notify_post("com.duck1001.splitover/prefsChanged");
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    // 进页面时把 bundle 里的默认值写一份，避免 tweak 侧读到空
    [self _seedDefaultsIfNeeded];
}

- (void)_seedDefaultsIfNeeded {
    CFPreferencesAppSynchronize(CFSTR("com.duck1001.splitover"));
    CFPropertyListRef value = CFPreferencesCopyAppValue(CFSTR("enabled"), CFSTR("com.duck1001.splitover"));
    if (value) { CFRelease(value); return; }

    NSDictionary *defaults = @{
        @"enabled": @YES,
        @"padEnabled": @YES,
        @"padAutoCollapse": @YES,
        @"padCorner": @(0),
        @"gestureEdgeSwipe": @YES,
        @"gestureThreeFinger": @YES,
        @"gestureStatusBarDoubleTap": @NO,
        @"gestureHomeLongPress": @YES,
        @"edgeSensitivity": @(0.5),
        @"snapGap": @(8),
        @"cornerRadius": @(14),
        @"windowOpacity": @(1.0),
        @"keepAlive": @YES,
        @"forceMultiwindow": @YES,
    };
    for (NSString *key in defaults) {
        CFPreferencesSetAppValue((__bridge CFStringRef)key,
                                 (__bridge CFPropertyListRef)defaults[key],
                                 CFSTR("com.duck1001.splitover"));
    }
    CFPreferencesAppSynchronize(CFSTR("com.duck1001.splitover"));
}

@end
