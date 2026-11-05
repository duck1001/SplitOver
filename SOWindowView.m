//
//  SOWindowView.m
//  SplitOver
//

#import "SOWindowView.h"
#import "SOSceneHelper.h"
#import "SOSettings.h"
#import "SOOverlayWindow.h"
#import "SOAppHelper.h"
#import "SOWindowManager.h"
#import "SOSceneHost.h"

static const CGFloat kSOTitleHeight = 30.0;

@interface SOWindowView () <UIGestureRecognizerDelegate>
@property (nonatomic, strong) UIView *titleBar;
@property (nonatomic, strong) UIView *mainView;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UIButton *snapButton;
@property (nonatomic, strong) UIView *snapPreview;
@property (nonatomic, assign) CGPoint dragOffset;
@property (nonatomic, assign) CGPoint resizeStart;
@property (nonatomic, assign) CGRect resizeFrame;
@property (nonatomic, strong) UIView *resizeHandle;      // 右下
@property (nonatomic, strong) UIView *resizeHandleLeft;  // 左下
@property (nonatomic, strong) UIView *bottomCloseZone;   // 底边中间，点一下关窗

- (UIView *)_cornerGrip;
- (UIView *)_closePill;
- (void)resizePanLeft:(UIPanGestureRecognizer *)gesture;
@end

@implementation SOWindowView

- (instancetype)initWithContentView:(UIView *)contentView
                           bundleID:(NSString *)bundleID
                              scene:(FBScene *)scene {
    if ((self = [super initWithFrame:CGRectMake(0, 0, 320, 420)])) {
        _bundleID = [bundleID copy];
        _isOpen = YES;
        _snap = SOSnapFree;

        self.backgroundColor = [UIColor clearColor];
        self.layer.cornerRadius = SOSettings.shared.cornerRadius;
        self.layer.masksToBounds = YES;
        self.layer.borderWidth = 0.5;
        self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.22].CGColor;
        self.alpha = SOSettings.shared.windowOpacity;

        // 标题栏
        _titleBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width, kSOTitleHeight)];
        _titleBar.backgroundColor = [UIColor colorWithWhite:0.16 alpha:0.96];
        _titleBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self addSubview:_titleBar];

        _iconView = [[UIImageView alloc] initWithFrame:CGRectMake(9, 7, 16, 16)];
        _iconView.layer.cornerRadius = 3.5;
        _iconView.layer.masksToBounds = YES;
        [_titleBar addSubview:_iconView];

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(32, 0, self.bounds.size.width - 110, kSOTitleHeight)];
        _titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _titleLabel.textColor = [UIColor whiteColor];
        _titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
        [_titleBar addSubview:_titleLabel];

        _closeButton = [self _titleButtonWithImage:@"xmark" action:@selector(closeTapped) x:self.bounds.size.width - 26];
        [_titleBar addSubview:_closeButton];

        _snapButton = [self _titleButtonWithImage:@"rectangle.split.2x1" action:@selector(snapTapped) x:self.bounds.size.width - 50];
        [_titleBar addSubview:_snapButton];

        // 内容区
        _mainView = [[UIView alloc] initWithFrame:CGRectMake(0, kSOTitleHeight,
                                                            self.bounds.size.width,
                                                            self.bounds.size.height - kSOTitleHeight)];
        _mainView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _mainView.backgroundColor = [UIColor blackColor];
        _mainView.clipsToBounds = YES;
        [self addSubview:_mainView];
        // 场景宿主自己负责挂载 / 重连 / 快照兜底，不会再出现纯黑窗口
        _sceneHost = [[SOSceneHost alloc] initWithBundleID:bundleID];
        _sceneHost.view.frame = _mainView.bounds;
        _sceneHost.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [_mainView addSubview:_sceneHost.view];

        // 左右下角缩放手柄
        _resizeHandle = [self _cornerGrip];
        _resizeHandle.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
        [self addSubview:_resizeHandle];

        _resizeHandleLeft = [self _cornerGrip];
        _resizeHandleLeft.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
        [self addSubview:_resizeHandleLeft];

        // 底边中间：点一下直接关窗
        _bottomCloseZone = [[UIView alloc] initWithFrame:CGRectZero];
        _bottomCloseZone.backgroundColor = [UIColor clearColor];
        _bottomCloseZone.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        [_bottomCloseZone addSubview:[self _closePill]];
        [self addSubview:_bottomCloseZone];

        UIPanGestureRecognizer *titlePan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(titlePan:)];
        titlePan.delegate = self;
        [_titleBar addGestureRecognizer:titlePan];

        UIPanGestureRecognizer *resizePan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(resizePan:)];
        [_resizeHandle addGestureRecognizer:resizePan];

        UIPanGestureRecognizer *resizePanLeft = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(resizePanLeft:)];
        [_resizeHandleLeft addGestureRecognizer:resizePanLeft];

        UITapGestureRecognizer *closeTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(closeTapped)];
        [_bottomCloseZone addGestureRecognizer:closeTap];

        UILongPressGestureRecognizer *titleLong = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(titleLong:)];
        titleLong.minimumPressDuration = 0.45;
        [_titleBar addGestureRecognizer:titleLong];

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(focusTapped)];
        [self addGestureRecognizer:tap];

        [self setTitleText:[SOAppHelper displayNameForBundleID:bundleID]
                      icon:[SOAppHelper iconForBundleID:bundleID size:32]];
        [self relayoutContent];
    }
    return self;
}

- (UIButton *)_titleButtonWithImage:(NSString *)symbol action:(SEL)action x:(CGFloat)x {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.frame = CGRectMake(x, 5, 20, 20);
    button.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    button.tintColor = [UIColor colorWithWhite:0.92 alpha:1.0];
    UIImage *image = [UIImage systemImageNamed:symbol];
    [button setImage:image forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)setTitleText:(NSString *)title icon:(UIImage *)icon {
    self.titleLabel.text = title;
    self.iconView.image = icon;
}

#pragma mark - 布局与画面

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = self.bounds.size.width;
    self.titleBar.frame = CGRectMake(0, 0, width, kSOTitleHeight);
    self.mainView.frame = CGRectMake(0, kSOTitleHeight, width, self.bounds.size.height - kSOTitleHeight);
    CGFloat h = self.bounds.size.height;
    self.resizeHandle.frame = CGRectMake(width - 26, h - 26, 26, 26);
    self.resizeHandleLeft.frame = CGRectMake(0, h - 26, 26, 26);
    CGFloat closeWidth = MAX(70.0, width * 0.42);
    self.bottomCloseZone.frame = CGRectMake((width - closeWidth) / 2.0, h - 34, closeWidth, 34);
    UIView *pill = self.bottomCloseZone.subviews.firstObject;
    pill.frame = CGRectMake((closeWidth - 34) / 2.0, 9, 34, 4);
    [self relayoutContent];
}

- (void)relayoutContent {
    if (!self.sceneHost) return;
    self.sceneHost.view.frame = self.mainView.bounds;
    [self.sceneHost setHostedFrame:self.mainView.bounds];
    [self.sceneHost commitHostedFrame];
}

- (void)updateLayers {
    if (!self.isOpen) return;
    [self.sceneHost retryAttach];
}

#pragma mark - 拖动 + 边缘吸附

- (void)titlePan:(UIPanGestureRecognizer *)gesture {
    CGPoint location = [gesture locationInView:self.superview];

    if (gesture.state == UIGestureRecognizerStateBegan) {
        self.dragOffset = CGPointMake(location.x - self.center.x, location.y - self.center.y);
        [self.superview bringSubviewToFront:self];
        if (self.onFocus) self.onFocus(self);
    }
    if (gesture.state == UIGestureRecognizerStateChanged) {
        self.center = CGPointMake(location.x - self.dragOffset.x, location.y - self.dragOffset.y);
        [self _updateSnapPreviewAtPoint:location];
    }
    if (gesture.state == UIGestureRecognizerStateEnded ||
        gesture.state == UIGestureRecognizerStateCancelled) {
        SOSnap snap = [self _snapForPoint:location];
        [self _hideSnapPreview];
        if (snap != SOSnapFree && self.onSnapRequest) {
            self.onSnapRequest(self, snap);
        } else if (self.snap != SOSnapFree) {
            // 拖离吸附位置就自由浮动
            if (self.onSnapRequest) self.onSnapRequest(self, SOSnapFree);
        }
    }
}

- (SOSnap)_snapForPoint:(CGPoint)point {
    CGSize screen = [UIScreen mainScreen].bounds.size;
    CGFloat edge = 64.0;
    BOOL left = point.x < edge;
    BOOL right = point.x > screen.width - edge;
    BOOL top = point.y < edge;

    if (left && top) return SOSnapTopLeft;
    if (right && top) return SOSnapTopRight;
    if (left) return SOSnapLeft;
    if (right) return SOSnapRight;
    if (top) return SOSnapFull;
    return SOSnapFree;
}

- (void)_updateSnapPreviewAtPoint:(CGPoint)point {
    SOSnap snap = [self _snapForPoint:point];
    if (snap == SOSnapFree) { [self _hideSnapPreview]; return; }

    if (!self.snapPreview) {
        self.snapPreview = [[UIView alloc] initWithFrame:CGRectZero];
        self.snapPreview.backgroundColor = [UIColor colorWithRed:0.35 green:0.78 blue:1.0 alpha:0.18];
        self.snapPreview.layer.borderColor = [UIColor colorWithRed:0.35 green:0.78 blue:1.0 alpha:0.65].CGColor;
        self.snapPreview.layer.borderWidth = 1.5;
        self.snapPreview.layer.cornerRadius = 10;
        self.snapPreview.userInteractionEnabled = NO;
    }
    if (!self.snapPreview.superview) [self.superview addSubview:self.snapPreview];

    CGRect screenRect = [UIScreen mainScreen].bounds;
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    CGFloat topInset = (keyWindow && keyWindow.safeAreaInsets.top > 0) ? keyWindow.safeAreaInsets.top : 44.0;
    screenRect.origin.y += topInset;
    screenRect.size.height -= topInset;
    CGRect frame = [SOSnapGeometry frameForSnap:snap screen:screenRect gap:SOSettings.shared.snapGap];
    [UIView animateWithDuration:0.12 animations:^{ self.snapPreview.frame = frame; }];
}

- (void)_hideSnapPreview {
    [UIView animateWithDuration:0.1 animations:^{ self.snapPreview.alpha = 0; } completion:^(BOOL finished) {
        [self.snapPreview removeFromSuperview];
        self.snapPreview.alpha = 1;
    }];
}

#pragma mark - 缩放

- (void)resizePan:(UIPanGestureRecognizer *)gesture {
    CGPoint point = [gesture locationInView:self.superview];
    if (gesture.state == UIGestureRecognizerStateBegan) {
        self.resizeStart = point;
        self.resizeFrame = self.frame;
        if (self.onFocus) self.onFocus(self);
    }
    if (gesture.state != UIGestureRecognizerStateChanged) return;

    CGFloat dx = point.x - self.resizeStart.x;
    CGFloat dy = point.y - self.resizeStart.y;
    CGFloat minW = 180, minH = 160;
    CGFloat width = MAX(minW, self.resizeFrame.size.width + dx);
    CGFloat height = MAX(minH, self.resizeFrame.size.height + dy);
    CGRect frame = self.resizeFrame;
    frame.size = CGSizeMake(width, height);
    self.frame = frame;
    if (self.snap != SOSnapFree) {
        self.snap = SOSnapFree;
        if (self.onSnapRequest) self.onSnapRequest(self, SOSnapFree);
    }
}

#pragma mark - 按钮

- (UIView *)_cornerGrip {
    UIView *grip = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 26, 26)];
    grip.backgroundColor = [UIColor clearColor];
    UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(15, 15, 6, 6)];
    dot.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.34];
    dot.layer.cornerRadius = 3;
    dot.userInteractionEnabled = NO;
    [grip addSubview:dot];
    return grip;
}

- (UIView *)_closePill {
    UIView *pill = [[UIView alloc] initWithFrame:CGRectMake(0, 9, 34, 4)];
    pill.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.28];
    pill.layer.cornerRadius = 2;
    pill.userInteractionEnabled = NO;
    return pill;
}

- (void)resizePanLeft:(UIPanGestureRecognizer *)gesture {
    CGPoint point = [gesture locationInView:self.superview];
    if (gesture.state == UIGestureRecognizerStateBegan) {
        self.resizeStart = point;
        self.resizeFrame = self.frame;
        if (self.onFocus) self.onFocus(self);
    }
    if (gesture.state != UIGestureRecognizerStateChanged) return;

    CGFloat dx = point.x - self.resizeStart.x;
    CGFloat dy = point.y - self.resizeStart.y;
    CGRect old = self.resizeFrame;
    CGFloat minW = 180, minH = 160;
    CGFloat newW = MAX(minW, old.size.width - dx);
    CGFloat newH = MAX(minH, old.size.height - dy);
    self.frame = CGRectMake(old.origin.x + (old.size.width - newW),
                            old.origin.y + (old.size.height - newH),
                            newW, newH);
    if (self.snap != SOSnapFree) {
        self.snap = SOSnapFree;
        if (self.onSnapRequest) self.onSnapRequest(self, SOSnapFree);
    }
}

- (void)closeTapped {
    if (self.onClose) self.onClose(self);
}

- (void)snapTapped {
    static const SOSnap cycle[] = { SOSnapFree, SOSnapLeft, SOSnapRight, SOSnapFull };
    int index = 0;
    for (int i = 0; i < 4; i++) if (cycle[i] == self.snap) index = i;
    SOSnap next = cycle[(index + 1) % 4];
    if (self.onSnapRequest) self.onSnapRequest(self, next);
}

- (void)titleLong:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:[SOAppHelper displayNameForBundleID:self.bundleID]
                                                                  message:nil
                                                           preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *titles = @[@"全屏", @"左半屏", @"右半屏", @"左上", @"右上", @"自由"];
    NSArray *values = @[@(SOSnapFull), @(SOSnapLeft), @(SOSnapRight),
                        @(SOSnapTopLeft), @(SOSnapTopRight), @(SOSnapFree)];
    for (NSUInteger i = 0; i < titles.count; i++) {
        SOSnap snap = (SOSnap)[values[i] integerValue];
        [sheet addAction:[UIAlertAction actionWithTitle:titles[i] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            if (self.onSnapRequest) self.onSnapRequest(self, snap);
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"关闭窗口" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        if (self.onClose) self.onClose(self);
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];

    UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (root.presentedViewController) root = root.presentedViewController;
    [root presentViewController:sheet animated:YES completion:nil];
}

- (void)focusTapped {
    if (self.onFocus) self.onFocus(self);
}

@end
