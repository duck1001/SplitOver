//
//  SOOverlayWindow.h
//  SplitOver — 触摸穿透宿主窗口
//

#import "SOPrivate.h"

@interface SOPassthroughView : UIView
@end

@interface SOOverlayWindow : UIWindow

+ (instancetype)shared;
+ (void)setShared:(SOOverlayWindow *)window;

+ (BOOL)isWindowed:(NSString *)bundleID;
+ (void)addWindowed:(NSString *)bundleID;
+ (void)removeWindowed:(NSString *)bundleID;
+ (void)refreshAllWindows;

// 键盘等外部 layer 单独挂一个不旋转的窗口
+ (UIWindow *)keyboardHostWindow;

// 角部手势热区（64x64），由 SOGestureController 挂手势
- (UIView *)grabZoneForCorner:(BOOL)right;
- (CGRect)cornerAnchorRect:(BOOL)right;

@end
