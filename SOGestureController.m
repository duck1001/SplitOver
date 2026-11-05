//
//  SOGestureController.m
//  SplitOver
//

#import "SOGestureController.h"
#import "SOOverlayWindow.h"
#import "SOWheelController.h"
#import "SOSettings.h"

@interface SOGestureController () <UIGestureRecognizerDelegate>
@property (nonatomic, strong) NSMutableArray<UIGestureRecognizer *> *zoneRecognizers;
@property (nonatomic, strong) NSMutableArray<UIGestureRecognizer *> *globalRecognizers;
@end

@implementation SOGestureController

+ (instancetype)shared {
    static SOGestureController *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init {
    if ((self = [super init])) {
        _zoneRecognizers = [NSMutableArray array];
        _globalRecognizers = [NSMutableArray array];
    }
    return self;
}

#pragma mark - 角部热区

- (void)install {
    [self uninstall];
    SOOverlayWindow *window = [SOOverlayWindow shared];
    if (!window || !SOSettings.shared.gestureEdgeSwipe) return;

    for (NSInteger i = 0; i < 2; i++) {
        UIView *zone = [window grabZoneForCorner:(i == 1)];
        if (!zone) continue;
        zone.tag = 900 + i;

        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(zonePan:)];
        pan.maximumNumberOfTouches = 1;
        pan.minimumNumberOfTouches = 1;
        pan.cancelsTouchesInView = YES;
        pan.delegate = self;
        [zone addGestureRecognizer:pan];
        [self.zoneRecognizers addObject:pan];

        // 轻点角落也能把圆盘叫出来（点按模式）
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(zoneTap:)];
        tap.delegate = self;
        [zone addGestureRecognizer:tap];
        [self.zoneRecognizers addObject:tap];
    }
}

- (void)uninstall {
    for (UIGestureRecognizer *g in self.zoneRecognizers) [g.view removeGestureRecognizer:g];
    for (UIGestureRecognizer *g in self.globalRecognizers) [g.view removeGestureRecognizer:g];
    [self.zoneRecognizers removeAllObjects];
    [self.globalRecognizers removeAllObjects];
}

- (SOWheelCorner)cornerForZone:(UIView *)zone {
    return (zone.tag == 901) ? SOWheelCornerRight : SOWheelCornerLeft;
}

- (void)zonePan:(UIPanGestureRecognizer *)gesture {
    UIView *zone = gesture.view;
    UIView *root = zone.superview;
    SOWheelCorner corner = [self cornerForZone:zone];
    CGPoint point = [gesture locationInView:root];

    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:
            [[SOWheelController shared] presentFromCorner:corner];
            [[SOWheelController shared] updateWithPoint:point];
            break;
        case UIGestureRecognizerStateChanged:
            [[SOWheelController shared] updateWithPoint:point];
            break;
        case UIGestureRecognizerStateEnded:
            [[SOWheelController shared] commitSelection];
            break;
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
            [[SOWheelController shared] dismiss];
            break;
        default: break;
    }
}

- (void)zoneTap:(UITapGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateRecognized) return;
    SOWheelCorner corner = [self cornerForZone:gesture.view];
    [[SOWheelController shared] presentFromCorner:corner];
    [[SOWheelController shared] setSticky:YES];
}

#pragma mark - 全局手势

- (void)installOnSpringBoardView:(UIView *)view {
    if (!view) return;
    SOSettings *settings = SOSettings.shared;

    if (settings.gestureStatusBarDoubleTap) {
        UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(statusBarDoubleTap:)];
        doubleTap.numberOfTapsRequired = 2;
        doubleTap.delegate = self;
        [view addGestureRecognizer:doubleTap];
        [self.globalRecognizers addObject:doubleTap];
    }
    if (settings.gestureThreeFinger) {
        UISwipeGestureRecognizer *threeUp = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(threeFingerSwipe:)];
        threeUp.numberOfTouchesRequired = 3;
        threeUp.direction = UISwipeGestureRecognizerDirectionUp;
        threeUp.delegate = self;
        [view addGestureRecognizer:threeUp];
        [self.globalRecognizers addObject:threeUp];
    }
    if (settings.gestureHomeLongPress) {
        UILongPressGestureRecognizer *homeLong = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(homeLongPress:)];
        homeLong.minimumPressDuration = 0.4;
        homeLong.delegate = self;
        [view addGestureRecognizer:homeLong];
        [self.globalRecognizers addObject:homeLong];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    return YES;
}

- (void)statusBarDoubleTap:(UITapGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateRecognized) return;
    CGPoint point = [gesture locationInView:gesture.view];
    CGFloat threshold = 60.0;
    if (@available(iOS 11.0, *)) threshold = MAX(threshold, gesture.view.safeAreaInsets.top + 12);
    if (point.y > threshold) return;
    [self presentNearestCornerForPoint:point];
}

- (void)threeFingerSwipe:(UISwipeGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateEnded) return;
    [self presentNearestCornerForPoint:[gesture locationInView:gesture.view]];
}

- (void)homeLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    CGPoint point = [gesture locationInView:gesture.view];
    CGFloat zone = 30.0;
    if (@available(iOS 11.0, *)) zone = MAX(zone, gesture.view.safeAreaInsets.bottom + 10);
    if (point.y < gesture.view.bounds.size.height - zone) return;
    [self presentNearestCornerForPoint:point];
}

- (void)presentNearestCornerForPoint:(CGPoint)point {
    CGSize size = [UIScreen mainScreen].bounds.size;
    SOWheelCorner corner = (point.x < size.width / 2.0) ? SOWheelCornerLeft : SOWheelCornerRight;
    [[SOWheelController shared] presentFromCorner:corner];
    [[SOWheelController shared] setSticky:YES];
}

@end
