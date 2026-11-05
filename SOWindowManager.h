//
//  SOWindowManager.h
//  SplitOver — 窗口注册表与吸附布局
//

#import "SOWindowView.h"

@interface SOSnapGeometry : NSObject
+ (CGRect)frameForSnap:(SOSnap)snap screen:(CGRect)screen gap:(CGFloat)gap;
@end

@interface SOWindowManager : NSObject

+ (instancetype)shared;

@property (nonatomic, readonly) NSArray<SOWindowView *> *windows;
@property (nonatomic, readonly) SOWindowView *focusedWindow;

- (SOWindowView *)openBundleID:(NSString *)bundleID snap:(SOSnap)snap;
// 从圆盘图标位置长出来（丝滑呼出）
- (SOWindowView *)openBundleID:(NSString *)bundleID snap:(SOSnap)snap fromPoint:(CGPoint)point;
- (void)closeWindow:(SOWindowView *)window;
- (void)closeAll;

- (void)applySnap:(SOSnap)snap toWindow:(SOWindowView *)window;
- (void)bringToFront:(SOWindowView *)window;

// 圆盘核心动作：当前 App 留一半，选中的 App 进另一半
- (void)splitWithBundleID:(NSString *)bundleID side:(SOSnap)side;
- (void)splitWithBundleID:(NSString *)bundleID side:(SOSnap)side fromPoint:(CGPoint)point;
- (void)swapSides;
- (void)reflow;

@end
