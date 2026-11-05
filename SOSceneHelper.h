//
//  SOSceneHelper.h
//  SplitOver — FBScene 查找 / 前台化 / 画面挂载
//

#import "SOPrivate.h"

@interface SOSceneHelper : NSObject

+ (FBScene *)sceneForBundleID:(NSString *)bundleID;
+ (FBScene *)sceneForBundleID:(NSString *)bundleID sceneID:(NSString *)sceneID;

+ (UIView *)createLayerHostViewForScene:(FBScene *)scene;
+ (void)setScene:(FBScene *)scene foreground:(BOOL)foreground;
+ (void)wakeSceneForBundleID:(NSString *)bundleID;

+ (void)startKeepAliveForBundleID:(NSString *)bundleID;
+ (void)stopKeepAliveForBundleID:(NSString *)bundleID;
+ (void)stopAllKeepAlive;

@end
