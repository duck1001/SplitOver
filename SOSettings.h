//
//  SOSettings.h
//  SplitOver
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

#define SO_PREFS_DOMAIN  @"com.duck1001.splitover"
#define SO_PREFS_CHANGED @"com.duck1001.splitover/prefsChanged"

typedef NS_ENUM(NSInteger, SOPadCorner) {
    SOPadCornerRight = 0,   // 右边缘居中
    SOPadCornerBottomRight,
    SOPadCornerBottomLeft,
    SOPadCornerLeft,
};

@interface SOSettings : NSObject

+ (instancetype)shared;

- (void)reload;
- (void)observeChanges;   // 注册 Darwin 通知，设置改动实时生效

@property (nonatomic, readonly) BOOL enabled;
@property (nonatomic, readonly) BOOL padEnabled;
@property (nonatomic, readonly) SOPadCorner padCorner;
@property (nonatomic, readonly) BOOL padAutoCollapse;

@property (nonatomic, readonly) BOOL gestureEdgeSwipe;
@property (nonatomic, readonly) BOOL gestureThreeFinger;
@property (nonatomic, readonly) BOOL gestureStatusBarDoubleTap;
@property (nonatomic, readonly) BOOL gestureHomeLongPress;
@property (nonatomic, readonly) BOOL gestureInApps;      // 注入 App 内的手势中继

@property (nonatomic, readonly) CGFloat edgeSensitivity;  // 0..1
@property (nonatomic, readonly) CGFloat snapGap;          // 窗口之间缝隙
@property (nonatomic, readonly) CGFloat cornerRadius;
@property (nonatomic, readonly) CGFloat windowOpacity;

@property (nonatomic, readonly) BOOL hapticsEnabled;
@property (nonatomic, readonly) CGFloat wheelIconSize;
@property (nonatomic, readonly) CGFloat wheelRadius;      // 0 = 自动
@property (nonatomic, readonly) CGFloat snapDuration;
@property (nonatomic, readonly) BOOL dimBackdrop;
@property (nonatomic, readonly) CGFloat floatWidth;       // 自由浮窗宽度占比

@property (nonatomic, readonly) BOOL keepAlive;          // 后台保活（RBS 断言）
@property (nonatomic, readonly) BOOL forceMultiwindow;   // 强制 App 支持多窗口

- (BOOL)scaleModeForBundleID:(NSString *)bundleID;       // 仅缩放画面，不要求 App 支持多窗口
- (void)setScaleMode:(BOOL)on forBundleID:(NSString *)bundleID;

- (CGPoint)padCenter;                                     // 操作盘上次位置
- (void)setPadCenter:(CGPoint)center;

@end
