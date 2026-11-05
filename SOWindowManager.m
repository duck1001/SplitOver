//
//  SOWindowManager.m
//  SplitOver
//

#import "SOWindowManager.h"
#import "SOSceneHelper.h"
#import "SOOverlayWindow.h"
#import "SOAppHelper.h"
#import "SOSettings.h"
#import "SOBackgrounderManager.h"

// 顶部让出状态栏：保证分屏时仍能从最上方下拉通知中心
static CGRect SOUsableScreen(void) {
    CGRect bounds = [UIScreen mainScreen].bounds;
    CGFloat top = 44.0;
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if (window && window.safeAreaInsets.top > 0) top = window.safeAreaInsets.top;
    return CGRectMake(bounds.origin.x, top, bounds.size.width, bounds.size.height - top);
}

@implementation SOSnapGeometry

+ (CGRect)frameForSnap:(SOSnap)snap screen:(CGRect)screen gap:(CGFloat)gap {
    CGFloat x = screen.origin.x, y = screen.origin.y;
    CGFloat w = screen.size.width, h = screen.size.height;
    CGFloat half = gap / 2.0;

    switch (snap) {
        case SOSnapFull:      return screen;
        case SOSnapLeft:      return CGRectMake(x, y, w / 2 - half, h);
        case SOSnapRight:     return CGRectMake(x + w / 2 + half, y, w / 2 - half, h);
        case SOSnapTop:       return CGRectMake(x, y, w, h / 2 - half);
        case SOSnapBottom:    return CGRectMake(x, y + h / 2 + half, w, h / 2 - half);
        case SOSnapTopLeft:   return CGRectMake(x, y, w / 2 - half, h / 2 - half);
        case SOSnapTopRight:  return CGRectMake(x + w / 2 + half, y, w / 2 - half, h / 2 - half);
        case SOSnapBottomLeft:  return CGRectMake(x, y + h / 2 + half, w / 2 - half, h / 2 - half);
        case SOSnapBottomRight: return CGRectMake(x + w / 2 + half, y + h / 2 + half, w / 2 - half, h / 2 - half);
        default: return CGRectZero;
    }
}

@end

@interface SOWindowManager ()
@property (nonatomic, strong) NSMutableArray<SOWindowView *> *mutableWindows;
@property (nonatomic, weak) SOWindowView *focused;
@end

@implementation SOWindowManager

+ (instancetype)shared {
    static SOWindowManager *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init {
    if ((self = [super init])) _mutableWindows = [NSMutableArray array];
    return self;
}

- (NSArray<SOWindowView *> *)windows { return [self.mutableWindows copy]; }
- (SOWindowView *)focusedWindow { return self.focused; }

#pragma mark - 开窗

- (SOWindowView *)openBundleID:(NSString *)bundleID snap:(SOSnap)snap {
    return [self openBundleID:bundleID snap:snap fromPoint:CGPointZero];
}

- (SOWindowView *)openBundleID:(NSString *)bundleID snap:(SOSnap)snap fromPoint:(CGPoint)point {
    if (!bundleID.length) return nil;

    for (SOWindowView *w in self.mutableWindows) {
        if ([w.bundleID isEqualToString:bundleID]) {
            if (snap != SOSnapFree) [self applySnap:snap toWindow:w];
            [self bringToFront:w];
            return w;
        }
    }
    if (self.mutableWindows.count >= 4) {
        [self closeWindow:self.mutableWindows.firstObject];
    }

    [[SOBackgrounderManager sharedInstance] setForeground:bundleID enabled:YES];
    [SOSceneHelper wakeSceneForBundleID:bundleID];

    SOOverlayWindow *host = [SOOverlayWindow shared];
    UIView *root = host.rootViewController.view;
    if (!root) return nil;

    SOWindowView *window = [[SOWindowView alloc] initWithContentView:nil bundleID:bundleID scene:nil];
    window.frame = CGRectMake(40, 120, 320, 440);
    __weak typeof(self) weakSelf = self;
    window.onClose = ^(SOWindowView *w) { [weakSelf closeWindow:w]; };
    window.onFocus = ^(SOWindowView *w) { [weakSelf bringToFront:w]; };
    window.onSnapRequest = ^(SOWindowView *w, SOSnap s) {
        if (s == SOSnapFree) {
            w.snap = SOSnapFree;
            [weakSelf reflow];
        } else {
            [weakSelf applySnap:s toWindow:w];
        }
    };
    [root addSubview:window];
    [self _animateWindowIn:window fromPoint:point snap:snap];
    [self.mutableWindows addObject:window];
    [SOOverlayWindow addWindowed:bundleID];
    [self applySnap:snap toWindow:window];
    [self bringToFront:window];

    [self _attachSceneForBundleID:bundleID toWindow:window attempts:0];
    return window;
}

- (void)_attachSceneForBundleID:(NSString *)bundleID toWindow:(SOWindowView *)window attempts:(int)attempts {
    if (!window.isOpen) return;
    FBScene *scene = [SOSceneHelper sceneForBundleID:bundleID];
    if (!scene && attempts == 0) {
        // 没在跑就后台挂起拉起，进程起来后场景才会出现（不能让 App 切前台盖住当前 App）
        Class springboard = NSClassFromString(@"SpringBoard");
        if ([springboard instancesRespondToSelector:@selector(launchApplicationWithIdentifier:suspended:)]) {
            [(id)[UIApplication sharedApplication] launchApplicationWithIdentifier:bundleID suspended:YES];
        }
    }
    if (!scene && attempts < 30) {
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
            [weakSelf _attachSceneForBundleID:bundleID toWindow:window attempts:attempts + 1];
        });
        return;
    }
    if (!scene) {
        NSLog(@"[SplitOver] scene not found for %@ after %d tries", bundleID, attempts);
        return;
    }
    [SOSceneHelper setScene:scene foreground:YES];
    UIView *content = [SOSceneHelper createLayerHostViewForScene:scene];
    if (!content) {
        NSLog(@"[SplitOver] no layer host for %@", bundleID);
        return;
    }
    window.scene = scene;
    window.contentView = content;
    content.alpha = 0;
    [window relayoutContent];
    [window updateLayers];
    [UIView animateWithDuration:0.28 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        content.alpha = 1;
    } completion:nil];
    [window setNeedsLayout];
}

#pragma mark - 出场动画

- (void)_animateWindowIn:(SOWindowView *)window fromPoint:(CGPoint)point snap:(SOSnap)snap {
    CGRect target = (snap == SOSnapFree)
        ? window.frame
        : [SOSnapGeometry frameForSnap:snap screen:SOUsableScreen() gap:SOSettings.shared.snapGap];

    BOOL fromWheel = !CGPointEqualToPoint(point, CGPointZero);
    CGPoint originCenter = fromWheel ? point : CGPointMake(CGRectGetMidX(target), CGRectGetMidY(target));

    window.alpha = 0;
    window.transform = CGAffineTransformMakeScale(fromWheel ? 0.18 : 0.88, fromWheel ? 0.18 : 0.88);
    window.center = originCenter;
    window.frame = CGRectMake(window.frame.origin.x, window.frame.origin.y,
                              target.size.width, target.size.height);
    window.center = originCenter;

    [UIView animateWithDuration:0.42 delay:0 usingSpringWithDamping:0.78 initialSpringVelocity:0.9
                        options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        window.alpha = SOSettings.shared.windowOpacity;
        window.transform = CGAffineTransformIdentity;
        window.frame = target;
    } completion:nil];
}

#pragma mark - 关窗

- (void)closeWindow:(SOWindowView *)window {
    if (!window) return;
    window.isOpen = NO;
    [SOSceneHelper stopKeepAliveForBundleID:window.bundleID];
    [SOOverlayWindow removeWindowed:window.bundleID];

    NSString *bid = window.bundleID;
    __weak typeof(self) weakSelf = self;
    [UIView animateWithDuration:0.22 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        window.alpha = 0;
        window.transform = CGAffineTransformMakeScale(0.9, 0.9);
    } completion:^(BOOL finished) {
        [window removeFromSuperview];
        [weakSelf.mutableWindows removeObject:window];
        if (weakSelf.focused == window) weakSelf.focused = nil;
        [weakSelf reflow];
        // 只关窗口，不杀进程；App 回到普通全屏状态
        NSLog(@"[SplitOver] closed window for %@", bid);
    }];
}

- (void)closeAll {
    for (SOWindowView *w in [self.mutableWindows copy]) [self closeWindow:w];
}

#pragma mark - 吸附

- (void)applySnap:(SOSnap)snap toWindow:(SOWindowView *)window {
    if (!window) return;
    window.snap = snap;
    if (snap == SOSnapFree) return;   // 自由浮动保留当前 frame

    CGRect frame = [SOSnapGeometry frameForSnap:snap screen:SOUsableScreen() gap:SOSettings.shared.snapGap];
    [UIView animateWithDuration:0.22 delay:0 usingSpringWithDamping:0.9 initialSpringVelocity:0.4
                        options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        window.frame = frame;
        [window layoutIfNeeded];
    } completion:nil];
    [self bringToFront:window];
}

- (void)bringToFront:(SOWindowView *)window {
    if (!window) return;
    self.focused = window;
    UIView *root = [SOOverlayWindow shared].rootViewController.view;
    [root bringSubviewToFront:window];
    // 非窗口的子视图（圆盘、预览层）永远压在窗口上面
    for (UIView *sub in root.subviews)
        if (![sub isKindOfClass:[SOWindowView class]])
            [root bringSubviewToFront:sub];
}

- (void)swapSides {
    SOWindowView *left = nil, *right = nil;
    for (SOWindowView *w in self.mutableWindows) {
        if (w.snap == SOSnapLeft) left = w;
        else if (w.snap == SOSnapRight) right = w;
    }
    if (left) [self applySnap:SOSnapRight toWindow:left];
    if (right) [self applySnap:SOSnapLeft toWindow:right];
}

#pragma mark - 圆盘分屏

- (void)splitWithBundleID:(NSString *)bundleID side:(SOSnap)side {
    [self splitWithBundleID:bundleID side:side fromPoint:CGPointZero];
}

- (void)splitWithBundleID:(NSString *)bundleID side:(SOSnap)side fromPoint:(CGPoint)point {
    if (!bundleID.length) return;
    // 只托管选中的 App：底层正在用的 App（快手之类）保持原样全屏播放，
    // 选中的 App 以半边悬浮窗盖上来，观感就是分屏。
    SOWindowView *window = [self openBundleID:bundleID snap:side fromPoint:point];
    if (!window) return;
    [self applySnap:side toWindow:window];
}

- (void)reflow {
    CGFloat gap = SOSettings.shared.snapGap;
    CGRect screen = SOUsableScreen();

    for (SOWindowView *w in self.mutableWindows) {
        if (w.snap == SOSnapFree) continue;
        CGRect target = [SOSnapGeometry frameForSnap:w.snap screen:screen gap:gap];
        if (!CGRectEqualToRect(w.frame, target)) {
            [UIView animateWithDuration:0.2 animations:^{ w.frame = target; }];
        }
    }
}

@end
