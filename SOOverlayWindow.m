//
//  SOOverlayWindow.m
//  SplitOver
//

#import "SOOverlayWindow.h"
#import "SOWindowView.h"

static SOOverlayWindow *_shared = nil;
static NSMutableArray<NSString *> *_windowedIDs = nil;
static UIWindow *_keyboardWindow = nil;

@implementation SOPassthroughView
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *view = [super hitTest:point withEvent:event];
    return (view == self) ? nil : view;
}
@end

@implementation SOOverlayWindow

+ (void)initialize {
    if (self == [SOOverlayWindow class]) _windowedIDs = [NSMutableArray array];
}

+ (instancetype)shared { return _shared; }
+ (void)setShared:(SOOverlayWindow *)window { _shared = window; }

+ (UIWindow *)keyboardHostWindow {
    if (!_keyboardWindow) {
        UIWindowScene *scene = nil;
        for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]]) { scene = (UIWindowScene *)s; break; }
        }
        _keyboardWindow = scene ? [[UIWindow alloc] initWithWindowScene:scene]
                                : [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        _keyboardWindow.frame = [UIScreen mainScreen].bounds;
        _keyboardWindow.backgroundColor = [UIColor clearColor];
        _keyboardWindow.windowLevel = UIWindowLevelAlert + 1000;
        _keyboardWindow.rootViewController = [UIViewController new];
        _keyboardWindow.rootViewController.view.backgroundColor = [UIColor clearColor];
        _keyboardWindow.hidden = NO;
    }
    return _keyboardWindow;
}

- (instancetype)init {
    UIWindowScene *scene = nil;
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]]) { scene = (UIWindowScene *)s; break; }
    }
    self = scene ? [super initWithWindowScene:scene] : [super initWithFrame:[UIScreen mainScreen].bounds];
    if (self) {
        self.frame = [UIScreen mainScreen].bounds;
        self.backgroundColor = [UIColor clearColor];
        self.windowLevel = UIWindowLevelAlert - 1;
        self.clipsToBounds = YES;

        UIViewController *vc = [UIViewController new];
        vc.view = [SOPassthroughView new];
        vc.view.backgroundColor = [UIColor clearColor];
        vc.view.frame = self.bounds;
        self.rootViewController = vc;

        [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(deviceOrientationDidChange:)
                                                     name:UIDeviceOrientationDidChangeNotification
                                                   object:nil];

        // 两个角部热区，常驻在最底层之上、窗口之下
        for (int i = 0; i < 2; i++) {
            UIView *zone = [[UIView alloc] initWithFrame:[self cornerAnchorRect:(i == 1)]];
            zone.backgroundColor = [UIColor clearColor];
            zone.autoresizingMask = UIViewAutoresizingFlexibleTopMargin |
                                    (i == 1 ? UIViewAutoresizingFlexibleLeftMargin : UIViewAutoresizingFlexibleRightMargin);
            [vc.view addSubview:zone];
        }
    }
    return self;
}

- (UIView *)grabZoneForCorner:(BOOL)right {
    UIView *root = self.rootViewController.view;
    NSInteger index = right ? 1 : 0;
    return root.subviews.count > index ? root.subviews[index] : nil;
}

- (CGRect)cornerAnchorRect:(BOOL)right {
    CGSize size = [UIScreen mainScreen].bounds.size;
    CGFloat w = 76, h = 96;
    CGFloat bottomInset = 34;
    if (@available(iOS 11.0, *)) {
        bottomInset = self.safeAreaInsets.bottom > 0 ? self.safeAreaInsets.bottom : 34;
    }
    return CGRectMake(right ? size.width - w : 0, size.height - h - bottomInset + 20, w, h);
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *view = [super hitTest:point withEvent:event];
    return (view == self) ? nil : view;
}

- (void)deviceOrientationDidChange:(NSNotification *)note {
    UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
    CGFloat angle = 0;
    switch (orientation) {
        case UIDeviceOrientationPortrait: angle = 0; break;
        case UIDeviceOrientationLandscapeLeft: angle = 90 * M_PI / 180.0; break;
        case UIDeviceOrientationLandscapeRight: angle = 270 * M_PI / 180.0; break;
        default: return;
    }
    [UIView animateWithDuration:0.3 animations:^{
        self.transform = CGAffineTransformMakeRotation(angle);
        self.frame = [UIScreen mainScreen].bounds;
        self.rootViewController.view.frame = self.bounds;
    }];
}

#pragma mark - 托管列表

+ (BOOL)isWindowed:(NSString *)bundleID {
    return bundleID && [_windowedIDs containsObject:bundleID];
}

+ (void)addWindowed:(NSString *)bundleID {
    if (bundleID && ![_windowedIDs containsObject:bundleID]) [_windowedIDs addObject:bundleID];
}

+ (void)removeWindowed:(NSString *)bundleID {
    if (bundleID) [_windowedIDs removeObject:bundleID];
}

+ (void)refreshAllWindows {
    SOOverlayWindow *window = _shared;
    if (!window) return;
    UIView *root = window.rootViewController.view ?: window;
    for (UIView *sub in root.subviews)
        if ([sub isKindOfClass:[SOWindowView class]])
            [(SOWindowView *)sub updateLayers];
}

@end
