//
//  SOWheelController.h
//  SplitOver — 左下/右下角呼出的分屏圆盘
//

#import "SOPrivate.h"

typedef NS_ENUM(NSInteger, SOWheelCorner) {
    SOWheelCornerLeft = 0,
    SOWheelCornerRight,
};

@interface SOWheelController : NSObject

+ (instancetype)shared;

@property (nonatomic, readonly, getter=isPresented) BOOL presented;

- (void)presentFromCorner:(SOWheelCorner)corner;
- (void)updateWithPoint:(CGPoint)pointInScreen;
- (void)commitSelection;
- (void)dismiss;
- (void)setSticky:(BOOL)sticky;   // 点按模式：圆盘常驻，等用户点图标

@end
