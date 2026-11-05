//
//  Tweak.x
//  SplitOver — SpringBoard 侧全部钩子
//

#import "SOPrivate.h"
#import "SOSettings.h"
#import "SOOverlayWindow.h"
#import "SOBackgrounderManager.h"
#import "SOSceneHelper.h"
#import "SOWindowManager.h"
#import "SOWheelController.h"
#import "SOGestureController.h"
#import "SOAppHelper.h"

#define SO_LOG(fmt, ...) NSLog(@"[SplitOver] " fmt, ##__VA_ARGS__)

static NSMutableDictionary<NSString *, RBSAssertion *> *_assertions = nil;

#pragma mark - appLayout → bundleID / sceneID

static id SOFindAppLayout(UIView *view) {
    UIView *current = view;
    while (current) {
        if ([current respondsToSelector:@selector(appLayout)]) {
            id layout = [(id)current appLayout];
            if (layout) return layout;
        }
        current = current.superview;
    }
    return nil;
}

static NSString *SOBundleIDFromLayout(id layout) {
    if (!layout) return nil;
    if ([layout respondsToSelector:@selector(allItems)]) {
        for (id item in [layout allItems])
            if ([item respondsToSelector:@selector(bundleIdentifier)])
                return [item bundleIdentifier];
    }
    if ([layout respondsToSelector:@selector(centerItem)]) {
        id item = [layout centerItem];
        if ([item respondsToSelector:@selector(bundleIdentifier)]) return [item bundleIdentifier];
    }
    id map = [layout respondsToSelector:@selector(rolesToLayoutItemsMap)]
        ? [layout rolesToLayoutItemsMap] : SOGetIvar(layout, "_rolesToLayoutItemsMap");
    if (map) {
        for (id item in [map allValues])
            if ([item respondsToSelector:@selector(bundleIdentifier)])
                return [item bundleIdentifier];
    }
    return nil;
}

static NSString *SOSceneIDFromLayout(id layout) {
    if (!layout) return nil;
    if ([layout respondsToSelector:@selector(allItems)]) {
        for (id item in [layout allItems])
            if ([item respondsToSelector:@selector(uniqueIdentifier)])
                return [item uniqueIdentifier];
    }
    if ([layout respondsToSelector:@selector(centerItem)]) {
        id item = [layout centerItem];
        if ([item respondsToSelector:@selector(uniqueIdentifier)]) return [item uniqueIdentifier];
    }
    return nil;
}

#pragma mark - 保活断言

static void SOAcquireAssertion(NSString *bundleID) {
    if (!bundleID || !SOSettings.shared.keepAlive) return;
    @try {
        Class ctrl = NSClassFromString(@"SBApplicationController");
        id app = [[ctrl performSelector:@selector(sharedInstance)]
                  performSelector:@selector(applicationWithBundleIdentifier:) withObject:bundleID];
        int pid = 0;
        if ([app respondsToSelector:@selector(pid)]) pid = [app pid];
        if (pid <= 0) return;

        Class targetClass = NSClassFromString(@"RBSTarget");
        Class attrClass = NSClassFromString(@"RBSLegacyAttribute");
        Class assertionClass = NSClassFromString(@"RBSAssertion");
        if (!targetClass || !attrClass || !assertionClass) return;

        id target = [targetClass performSelector:@selector(targetWithPid:) withObject:@(pid)];
        NSUInteger flags = BKSProcessAssertionPreventTaskSuspend |
                           BKSProcessAssertionPreventTaskThrottleDown |
                           BKSProcessAssertionWantsForegroundResourcePriority;
        id attr = [attrClass performSelector:@selector(attributeWithReason:flags:)
                                  withObject:@(BKSProcessAssertionReasonBackgroundUI)
                                  withObject:@(flags)];
        id assertion = [[assertionClass alloc] initWithExplanation:@"SplitOver keep alive"
                                                            target:target
                                                        attributes:@[attr]];
        NSError *error = nil;
        if ([assertion acquireWithError:&error]) {
            _assertions[bundleID] = assertion;
            SO_LOG(@"assertion acquired for %@ pid %d", bundleID, pid);
        } else {
            SO_LOG(@"assertion failed for %@: %@", bundleID, error);
        }
    } @catch (NSException *e) { SO_LOG(@"assertion exception: %@", e); }
}

static void SOReleaseAssertion(NSString *bundleID) {
    if (!bundleID) return;
    RBSAssertion *assertion = _assertions[bundleID];
    if (assertion) {
        [assertion invalidate];
        [_assertions removeObjectForKey:bundleID];
    }
}

#pragma mark - 钩子

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    _assertions = [NSMutableDictionary dictionary];
    [SOSettings.shared observeChanges];
    SO_LOG(@"loaded on iOS %@", [[UIDevice currentDevice] systemVersion]);

    SOOverlayWindow *window = [[SOOverlayWindow alloc] init];
    [SOOverlayWindow setShared:window];
    window.hidden = NO;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 300 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        [[SOGestureController shared] install];
        UIView *root = window.rootViewController.view;
        if (root) [[SOGestureController shared] installOnSpringBoardView:root];
    });

    // 设置改动即时生效：重挂手势 + 刷新窗口外观
    [[NSNotificationCenter defaultCenter] addObserverForName:SO_PREFS_CHANGED
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        [[SOGestureController shared] install];
        UIView *root = window.rootViewController.view;
        if (root) [[SOGestureController shared] installOnSpringBoardView:root];
        for (UIView *sub in root.subviews) {
            if (![sub isKindOfClass:[SOWindowView class]]) continue;
            sub.layer.cornerRadius = SOSettings.shared.cornerRadius;
            sub.alpha = SOSettings.shared.windowOpacity;
        }
    }];
}

%end

// App 侧画面需要多窗口能力：默认放开，按配置逐 App 处理
%hook SBApplicationInfo
- (BOOL)supportsMultiwindow {
    if (SOSettings.shared.forceMultiwindow) return YES;
    return %orig;
}
- (BOOL)wantsExclusiveForeground {
    if (SOSettings.shared.forceMultiwindow) return NO;
    return %orig;
}
%end

%hook SBApplication
- (BOOL)isMedusaCapable {
    if ([SOSettings.shared scaleModeForBundleID:self.bundleIdentifier]) return YES;
    if (SOSettings.shared.forceMultiwindow) return YES;
    return %orig;
}

- (void)_didExitWithContext:(id)context {
    NSString *bundleID = self.bundleIdentifier;
    if (bundleID) {
        SOReleaseAssertion(bundleID);
    }
    %orig;
}
%end

// 后台卡片长按 → 开窗
%hook SBFluidSwitcherItemContainer
- (id)initWithFrame:(CGRect)frame {
    id result = %orig;
    if (result) {
        UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc]
            initWithTarget:result action:@selector(so_openWindowAction:)];
        press.minimumPressDuration = 0.5;
        [(UIView *)result addGestureRecognizer:press];
    }
    return result;
}

%new
- (void)so_openWindowAction:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    id layout = [self respondsToSelector:@selector(appLayout)] ? [(id)self appLayout] : nil;
    if (!layout) layout = SOFindAppLayout((UIView *)self);
    NSString *bundleID = SOBundleIDFromLayout(layout);
    NSString *sceneID = SOSceneIDFromLayout(layout);
    if (!bundleID.length) return;

    [[SOWindowManager shared] openBundleID:bundleID sceneID:sceneID snap:SOSnapRight];
    SOAcquireAssertion(bundleID);

    Class switcherClass = NSClassFromString(@"SBMainSwitcherViewController");
    Class layoutClass = NSClassFromString(@"SBAppLayout");
    if (switcherClass && layoutClass && [layoutClass respondsToSelector:@selector(homeScreenAppLayout)]) {
        id switcher = [switcherClass performSelector:@selector(sharedInstance)];
        if ([switcher respondsToSelector:@selector(_dismissSwitcherNoninteractivelyToAppLayout:dismissFloatingSwitcher:animated:)]) {
            [switcher _dismissSwitcherNoninteractivelyToAppLayout:[layoutClass homeScreenAppLayout]
                                           dismissFloatingSwitcher:YES animated:YES];
        }
    }
}
%end

// 老系统兜底
%hook SBAppSwitcherPageView
- (id)initWithFrame:(CGRect)frame {
    id result = %orig;
    if (result) {
        UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc]
            initWithTarget:result action:@selector(so_openWindowAction:)];
        press.minimumPressDuration = 0.5;
        [(UIView *)result addGestureRecognizer:press];
    }
    return result;
}

%new
- (void)so_openWindowAction:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    id layout = SOFindAppLayout((UIView *)self);
    NSString *bundleID = SOBundleIDFromLayout(layout);
    if (!bundleID.length) return;
    [[SOWindowManager shared] openBundleID:bundleID snap:SOSnapRight];
    SOAcquireAssertion(bundleID);
}
%end

// 桌面图标 3D Touch 菜单：在窗口中打开
%hook SBIconView
- (NSArray *)applicationShortcutItems {
    NSArray *orig = %orig;
    NSString *appID = nil;
    if ([self respondsToSelector:@selector(applicationBundleIdentifier)])
        appID = [self applicationBundleIdentifier];
    if (!appID) return orig;

    Class itemClass = NSClassFromString(@"SBSApplicationShortcutItem");
    if (!itemClass) return orig;

    id item = [[itemClass alloc] init];
    [item setValue:@"在窗口中打开" forKey:@"localizedTitle"];
    [item setValue:@"com.duck1001.splitover.openwindow" forKey:@"type"];
    [item setValue:appID forKey:@"bundleIdentifierToLaunch"];
    return orig ? [orig arrayByAddingObject:item] : @[item];
}

+ (void)activateShortcut:(id)item withBundleIdentifier:(NSString *)bundleID forIconView:(id)iconView {
    NSString *type = [item respondsToSelector:@selector(type)] ? [item performSelector:@selector(type)] : nil;
    if (![type isEqualToString:@"com.duck1001.splitover.openwindow"]) {
        %orig;
        return;
    }
    [(SpringBoard *)[UIApplication sharedApplication] launchApplicationWithIdentifier:bundleID suspended:YES];
    SOAcquireAssertion(bundleID);

    __block int attempts = 0;
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(timer, dispatch_walltime(NULL, 0), 300 * NSEC_PER_MSEC, 50 * NSEC_PER_MSEC);
    dispatch_source_set_event_handler(timer, ^{
        attempts++;
        if (attempts > 20) { dispatch_source_cancel(timer); return; }
        if (![SOSceneHelper sceneForBundleID:bundleID]) return;
        dispatch_source_cancel(timer);
        [[SOWindowManager shared] openBundleID:bundleID snap:SOSnapRight];
    });
    dispatch_resume(timer);
}
%end

// 托管中的场景强制保持前台状态（iOS 16 的 deactivation 会单独下发）
%hook UIMutableApplicationSceneSettings
- (void)setDeactivationReasons:(unsigned long long)reasons {
    if (reasons != 0) {
        SOBackgrounderManager *manager = [SOBackgrounderManager sharedInstance];
        NSString *identifier = nil;
        for (NSString *name in @[@"_identifier", @"_sceneIdentifier", @"_bundleIdentifier"]) {
            identifier = SOGetIvar(self, name.UTF8String);
            if (identifier) break;
        }
        if (!identifier && [self respondsToSelector:@selector(identifier)])
            identifier = [(id)self performSelector:@selector(identifier)];

        if (identifier) {
            for (NSString *bundleID in manager.foregroundBundleIDs)
                if ([identifier containsString:bundleID]) { %orig(0); return; }
            for (NSString *sceneID in manager.foregroundSceneIDs)
                if ([identifier containsString:sceneID]) { %orig(0); return; }
        } else if (manager.foregroundBundleIDs.count) {
            %orig(0);
            return;
        }
    }
    %orig;
}
%end

%hook FBSceneLayerManager
- (void)_setLayers:(id)layers {
    %orig;
    [SOOverlayWindow refreshAllWindows];
}
%end

#pragma mark - 构造

%ctor {
    @autoreleasepool {
        [SOSettings.shared reload];
        [SOBackgrounderManager sharedInstance];
        SO_LOG(@"ctor done");
        %init;
    }
}
