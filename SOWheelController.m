//
//  SOWheelController.m
//  SplitOver
//

#import "SOWheelController.h"
#import "SOAppHelper.h"
#import "SOSettings.h"
#import "SOWindowManager.h"
#import "SOOverlayWindow.h"

static const CGFloat kSOWheelHubSize  = 54.0;

#pragma mark - 单个图标

@interface SOWheelItemView : UIView
@property (nonatomic, copy) NSString *bundleID;
- (instancetype)initWithBundleID:(NSString *)bundleID size:(CGFloat)size;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, assign) CGFloat angle;
@end

@implementation SOWheelItemView

- (instancetype)initWithBundleID:(NSString *)bundleID size:(CGFloat)size {
    if ((self = [super initWithFrame:CGRectMake(0, 0, size, size)])) {
        _bundleID = [bundleID copy];

        UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:
            [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
        blur.frame = self.bounds;
        blur.layer.cornerRadius = 14;
        blur.layer.masksToBounds = YES;
        blur.userInteractionEnabled = NO;
        [self addSubview:blur];

        _iconView = [[UIImageView alloc] initWithFrame:CGRectInset(self.bounds, size * 0.13, size * 0.13)];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.image = [SOAppHelper iconForBundleID:bundleID size:size * 2];
        _iconView.layer.cornerRadius = 10;
        _iconView.layer.masksToBounds = YES;
        [self addSubview:_iconView];

        self.layer.cornerRadius = 14;
        self.layer.borderWidth = 1.0;
        self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.16].CGColor;
    }
    return self;
}

@end

#pragma mark - 圆盘本体

@interface SOWheelView : UIView {
    CGPoint _anchor;
    CGFloat _radius;
}
@property (nonatomic, assign) SOWheelCorner corner;
@property (nonatomic, copy) NSArray<NSString *> *apps;
@property (nonatomic, strong) NSMutableArray<SOWheelItemView *> *items;
@property (nonatomic, strong) UIView *hub;
@property (nonatomic, strong) UILabel *hubLabel;
@property (nonatomic, strong) UILabel *hintLabel;
@property (nonatomic, strong) UIImageView *ghostIcon;
@property (nonatomic, assign) NSInteger selectedIndex;

- (void)updateSelectionForPoint:(CGPoint)point;
- (void)selectIndex:(NSInteger)index haptic:(BOOL)haptic;
- (NSString *)selectedBundleID;
@end

@implementation SOWheelView

- (instancetype)initWithCorner:(SOWheelCorner)corner apps:(NSArray<NSString *> *)apps {
    if ((self = [super initWithFrame:[UIScreen mainScreen].bounds])) {
        _corner = corner;
        _apps = [apps copy];
        _items = [NSMutableArray array];
        _selectedIndex = -1;
        self.backgroundColor = SOSettings.shared.dimBackdrop
            ? [UIColor colorWithWhite:0.0 alpha:0.14] : [UIColor colorWithWhite:0.0 alpha:0.001];

        [self _buildHint];
        [self _buildGhost];
        [self _buildItems];
        [self _buildHub];
        [self _computeGeometry];
    }
    return self;
}

- (void)_buildHint {
    self.hintLabel = [[UILabel alloc] init];
    self.hintLabel.text = @"滑动选择 · 松手分屏";
    self.hintLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    self.hintLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.65];
    self.hintLabel.textAlignment = NSTextAlignmentCenter;
    [self addSubview:self.hintLabel];
}

- (void)_buildGhost {
    NSString *foreground = [SOAppHelper foregroundBundleID];
    self.ghostIcon = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
    self.ghostIcon.contentMode = UIViewContentModeScaleAspectFit;
    self.ghostIcon.alpha = 0.35;
    self.ghostIcon.layer.cornerRadius = 9;
    self.ghostIcon.layer.masksToBounds = YES;
    self.ghostIcon.image = foreground ? [SOAppHelper iconForBundleID:foreground size:80] : nil;
    [self addSubview:self.ghostIcon];
}

- (void)_buildItems {
    CGFloat size = SOSettings.shared.wheelIconSize;
    for (NSString *bundleID in self.apps) {
        SOWheelItemView *item = [[SOWheelItemView alloc] initWithBundleID:bundleID size:size];
        [self addSubview:item];
        [self.items addObject:item];
    }
}

- (void)_buildHub {
    self.hub = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kSOWheelHubSize, kSOWheelHubSize)];
    self.hub.backgroundColor = [UIColor colorWithWhite:0.14 alpha:0.92];
    self.hub.layer.cornerRadius = kSOWheelHubSize / 2;
    self.hub.layer.borderWidth = 1.0;
    self.hub.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.22].CGColor;

    self.hubLabel = [[UILabel alloc] initWithFrame:self.hub.bounds];
    self.hubLabel.text = @"分屏";
    self.hubLabel.textAlignment = NSTextAlignmentCenter;
    self.hubLabel.textColor = [UIColor whiteColor];
    self.hubLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    [self.hub addSubview:self.hubLabel];
    [self addSubview:self.hub];
}

- (void)_computeGeometry {
    CGSize screen = self.bounds.size;
    CGFloat bottomInset = 34;
    if (@available(iOS 11.0, *)) {
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        bottomInset = window.safeAreaInsets.bottom > 0 ? window.safeAreaInsets.bottom : 34;
    }
    CGFloat inset = 30;
    _anchor = CGPointMake(self.corner == SOWheelCornerLeft ? inset : screen.width - inset,
                          screen.height - bottomInset - 26);

    NSInteger n = MAX(1, (NSInteger)self.items.count);
    CGFloat fixedRadius = SOSettings.shared.wheelRadius;
    _radius = fixedRadius > 0 ? fixedRadius : MIN(232.0, 118.0 + n * 18.0);

    self.hub.center = _anchor;
    self.hintLabel.frame = CGRectMake(0, _anchor.y - _radius - 34, screen.width, 16);
    self.ghostIcon.center = CGPointMake(self.corner == SOWheelCornerLeft ? screen.width - 40 : 40,
                                        screen.height - bottomInset - 40);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    NSInteger n = MAX(1, (NSInteger)self.items.count);
    for (NSInteger i = 0; i < (NSInteger)self.items.count; i++) {
        SOWheelItemView *item = self.items[i];
        CGFloat t = ((CGFloat)i + 0.5) / (CGFloat)n * (M_PI / 2.0);
        item.angle = t;
        CGFloat sign = (self.corner == SOWheelCornerLeft) ? 1.0 : -1.0;
        CGPoint center = CGPointMake(_anchor.x + sign * _radius * cos(t),
                                     _anchor.y - _radius * sin(t));
        item.center = center;
        item.transform = CGAffineTransformIdentity;
    }
}

#pragma mark - 选中

- (void)updateSelectionForPoint:(CGPoint)point {
    CGPoint delta = CGPointMake(point.x - _anchor.x, point.y - _anchor.y);
    CGFloat sign = (self.corner == SOWheelCornerLeft) ? 1.0 : -1.0;
    CGFloat dx = delta.x * sign;
    CGFloat dy = -delta.y;
    CGFloat distance = hypot(dx, dy);

    NSInteger index = -1;
    if (distance > 34) {
        CGFloat t = atan2(MAX(0.0, dy), MAX(0.0, dx));
        t = MAX(0.0, MIN(M_PI / 2.0, t));
        NSInteger n = MAX(1, (NSInteger)self.items.count);
        index = (NSInteger)floor(t / (M_PI / 2.0) * n);
        index = MAX(0, MIN(n - 1, index));
    }
    [self selectIndex:index haptic:YES];
}

- (void)selectIndex:(NSInteger)index haptic:(BOOL)haptic {
    if (index == self.selectedIndex) return;
    BOOL changed = (index >= 0);
    self.selectedIndex = index;

    for (NSInteger i = 0; i < (NSInteger)self.items.count; i++) {
        SOWheelItemView *item = self.items[i];
        BOOL on = (i == index);
        [UIView animateWithDuration:0.16 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
            item.transform = on ? CGAffineTransformMakeScale(1.24, 1.24) : CGAffineTransformIdentity;
            item.layer.borderColor = (on ? [UIColor colorWithRed:0.35 green:0.78 blue:1.0 alpha:0.95]
                                         : [UIColor colorWithWhite:1.0 alpha:0.16]).CGColor;
            item.alpha = (index < 0) ? 1.0 : (on ? 1.0 : 0.72);
        } completion:nil];
    }

    if (index >= 0 && index < (NSInteger)self.apps.count)
        self.hubLabel.text = [SOAppHelper displayNameForBundleID:self.apps[index]];
    else
        self.hubLabel.text = @"分屏";

    if (haptic && changed && SOSettings.shared.hapticsEnabled) {
        UISelectionFeedbackGenerator *gen = [UISelectionFeedbackGenerator new];
        [gen selectionChanged];
    }
}

- (NSString *)selectedBundleID {
    if (self.selectedIndex < 0 || self.selectedIndex >= (NSInteger)self.apps.count) return nil;
    return self.apps[self.selectedIndex];
}

@end

#pragma mark - 控制器

@interface SOWheelController ()
@property (nonatomic, strong) SOWheelView *wheel;
@property (nonatomic, assign) SOWheelCorner corner;
@property (nonatomic, assign) BOOL presented;
@property (nonatomic, assign) BOOL sticky;
@end

@implementation SOWheelController

+ (instancetype)shared {
    static SOWheelController *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (NSArray<NSString *> *)appsForWheel {
    NSArray *chosen = nil;
    // wheelApps 存的是用户勾选的 bundleID（顺序即排列顺序）
    CFPreferencesAppSynchronize((__bridge CFStringRef)SO_PREFS_DOMAIN);
    CFPropertyListRef value = CFPreferencesCopyAppValue(CFSTR("wheelApps"),
                                                        (__bridge CFStringRef)SO_PREFS_DOMAIN);
    if (value) {
        chosen = (__bridge_transfer NSArray *)value;
    }
    NSMutableArray *valid = [NSMutableArray array];
    for (id bid in chosen)
        if ([bid isKindOfClass:[NSString class]]) [valid addObject:bid];

    if (!valid.count) valid = [[SOAppHelper wheelFallbackApps] mutableCopy];
    if (valid.count > 8) valid = [[valid subarrayWithRange:NSMakeRange(0, 8)] mutableCopy];
    return valid;
}

- (void)presentFromCorner:(SOWheelCorner)corner {
    if (self.presented) return;
    if (!SOSettings.shared.padEnabled) return;

    NSArray *apps = [self appsForWheel];
    if (!apps.count) return;

    UIView *root = [SOOverlayWindow shared].rootViewController.view;
    if (!root) return;

    self.corner = corner;
    self.wheel = [[SOWheelView alloc] initWithCorner:corner apps:apps];
    self.wheel.alpha = 0;
    [root addSubview:self.wheel];
    [root bringSubviewToFront:self.wheel];

    self.presented = YES;
    [self.wheel layoutIfNeeded];

    // 逐个弹出
    for (NSInteger i = 0; i < (NSInteger)self.wheel.items.count; i++) {
        SOWheelItemView *item = self.wheel.items[i];
        item.transform = CGAffineTransformMakeScale(0.2, 0.2);
        item.alpha = 0;
        [UIView animateWithDuration:0.28 delay:0.02 * i
             usingSpringWithDamping:0.72 initialSpringVelocity:0.6
                            options:UIViewAnimationOptionBeginFromCurrentState animations:^{
            item.transform = CGAffineTransformIdentity;
            item.alpha = 1;
        } completion:nil];
    }
    [UIView animateWithDuration:0.18 animations:^{ self.wheel.alpha = 1; }];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_handleTap:)];
    [self.wheel addGestureRecognizer:tap];

    if (SOSettings.shared.hapticsEnabled) {
        UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [gen impactOccurred];
    }
}

- (void)setSticky:(BOOL)sticky { _sticky = sticky; }

- (void)_handleTap:(UITapGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateRecognized || !self.wheel) return;
    CGPoint point = [gesture locationInView:self.wheel];
    for (NSInteger i = 0; i < (NSInteger)self.wheel.items.count; i++) {
        SOWheelItemView *item = self.wheel.items[i];
        CGRect hit = CGRectInset(item.frame, -10, -10);
        if (CGRectContainsPoint(hit, point)) {
            [self.wheel selectIndex:i haptic:YES];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
                [self commitSelection];
            });
            return;
        }
    }
    [self dismiss];
}

- (void)updateWithPoint:(CGPoint)pointInScreen {
    if (!self.presented || !self.wheel) return;
    [self.wheel updateSelectionForPoint:pointInScreen];
}

- (void)commitSelection {
    if (!self.presented || !self.wheel) return;
    NSString *bundleID = [self.wheel selectedBundleID];
    SOWheelCorner corner = self.corner;

    CGPoint origin = self.wheel.hub.center;
    NSInteger index = self.wheel.selectedIndex;
    if (index >= 0 && index < (NSInteger)self.wheel.items.count)
        origin = self.wheel.items[index].center;

    [self dismiss];

    if (!bundleID) return;
    SOSnap side = (corner == SOWheelCornerLeft) ? SOSnapLeft : SOSnapRight;
    [[SOWindowManager shared] splitWithBundleID:bundleID side:side fromPoint:origin];

    if (SOSettings.shared.hapticsEnabled) {
        UINotificationFeedbackGenerator *gen = [UINotificationFeedbackGenerator new];
        [gen notificationOccurred:UINotificationFeedbackTypeSuccess];
    }
}

- (void)dismiss {
    if (!self.presented) return;
    self.presented = NO;
    SOWheelView *wheel = self.wheel;
    self.wheel = nil;

    // 图标收回中心 + 整体淡出
    CGPoint hub = wheel.hub.center;
    for (NSInteger i = 0; i < (NSInteger)wheel.items.count; i++) {
        SOWheelItemView *item = wheel.items[i];
        [UIView animateWithDuration:0.2 delay:0.012 * i options:UIViewAnimationOptionCurveEaseIn animations:^{
            item.center = hub;
            item.transform = CGAffineTransformMakeScale(0.2, 0.2);
            item.alpha = 0;
        } completion:nil];
    }
    [UIView animateWithDuration:0.2 animations:^{
        wheel.hub.transform = CGAffineTransformMakeScale(0.7, 0.7);
        wheel.hub.alpha = 0;
        wheel.hintLabel.alpha = 0;
        wheel.ghostIcon.alpha = 0;
    }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 260 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        [wheel removeFromSuperview];
    });
}

@end
