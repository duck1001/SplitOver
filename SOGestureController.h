//
//  SOGestureController.h
//  SplitOver — 角部呼出与全局手势
//

#import "SOPrivate.h"

@interface SOGestureController : NSObject

+ (instancetype)shared;

- (void)install;                              // 角部热区
- (void)uninstall;
- (void)installOnSpringBoardView:(UIView *)view;   // 状态栏双击 / 三指上滑 / Home 条长按

@end
