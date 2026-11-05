//
//  SOAppHelper.h
//  SplitOver — 应用列表 / 图标 / 前台 App
//

#import "SOPrivate.h"

@interface SOAppInfo : NSObject
@property (nonatomic, copy) NSString *bundleID;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) UIImage *icon;
@end

@interface SOAppHelper : NSObject

+ (NSArray<SOAppInfo *> *)installedApps;          // 已排序
+ (SOAppInfo *)appForBundleID:(NSString *)bundleID;
+ (NSString *)displayNameForBundleID:(NSString *)bundleID;
+ (UIImage *)iconForBundleID:(NSString *)bundleID size:(CGFloat)size;

+ (NSString *)foregroundBundleID;                 // 当前前台 App，排除我们托管的窗口
+ (BOOL)isAppRunning:(NSString *)bundleID;
+ (NSArray<NSString *> *)wheelFallbackApps;        // 设置里没选时用最近使用/常用

@end
