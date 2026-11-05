//
//  SOPrivate.h
//  SplitOver — 悬浮窗口分屏 + 操作盘
//  私有 API 声明，目标 iOS 15.0 – 16.x（rootless / roothide）
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach/mach.h>

#pragma mark - ivar helpers (ARC 下读写私有 ivar)

static inline id SOGetIvar(id obj, const char *name) {
    if (!obj) return nil;
    Ivar ivar = class_getInstanceVariable(object_getClass(obj), name);
    if (!ivar) ivar = class_getInstanceVariable([obj class], name);
    if (!ivar) return nil;
    void *ptr = (__bridge void *)obj;
    return (__bridge id)(*(void **)((char *)ptr + ivar_getOffset(ivar)));
}

static inline void SOSetIvarBool(id obj, const char *name, BOOL val) {
    if (!obj) return;
    Ivar ivar = class_getInstanceVariable(object_getClass(obj), name);
    if (!ivar) ivar = class_getInstanceVariable([obj class], name);
    if (!ivar) return;
    void *ptr = (__bridge void *)obj;
    *(BOOL *)((char *)ptr + ivar_getOffset(ivar)) = val;
}

static inline BOOL SOClassHasMethod(Class cls, SEL sel) {
    return cls && class_getInstanceMethod(cls, sel) != NULL;
}

#pragma mark - FrontBoard

@interface FBScene : NSObject
@property (nonatomic, readonly) NSString *identifier;
- (id)settings;
- (id)mutableSettings;
- (id)layerManager;
- (void)updateSettings:(id)settings withTransitionContext:(id)ctx;
- (void)updateSettings:(id)settings withTransitionContext:(id)ctx completion:(id)completion;
@end

@interface FBSceneManager : NSObject
+ (instancetype)sharedInstance;
@end

@interface FBSceneLayerManager : NSObject
- (NSArray *)layers;
@end

@interface FBSMutableSceneSettings : NSObject
@property (nonatomic, getter=isForeground) BOOL foreground;
@end

@interface UIMutableApplicationSceneSettings : NSObject
- (void)setDeactivationReasons:(unsigned long long)reasons;
- (unsigned long long)deactivationReasons;
@end

// iOS 16 的第三套渲染开关；iOS 15 上不存在，全部调用都要 respondsToSelector 保护
@interface _UISceneHostingActivationStateHostComponent : NSObject
- (void)setForeground:(BOOL)fg;
- (id)hostScene;
@end

#pragma mark - RunningBoard 进程断言

@interface RBSTarget : NSObject
+ (instancetype)targetWithPid:(int)pid;
@end

@interface RBSLegacyAttribute : NSObject
+ (instancetype)attributeWithReason:(NSUInteger)reason flags:(NSUInteger)flags;
@end

@interface RBSAssertion : NSObject
- (instancetype)initWithExplanation:(NSString *)explanation
                             target:(RBSTarget *)target
                         attributes:(NSArray *)attributes;
- (BOOL)acquireWithError:(NSError **)error;
- (void)invalidate;
@end

enum {
    BKSProcessAssertionPreventTaskSuspend        = (1 << 0),
    BKSProcessAssertionPreventTaskThrottleDown   = (1 << 1),
    BKSProcessAssertionWantsForegroundResourcePriority = (1 << 3),
    BKSProcessAssertionPreventThrottleDownUI     = (1 << 5),
};
enum { BKSProcessAssertionReasonBackgroundUI = 7 };

#pragma mark - SpringBoard

@interface SBApplication : NSObject
@property (nonatomic, readonly) NSString *bundleIdentifier;
@property (nonatomic, readonly) NSString *displayName;
- (BOOL)isMedusaCapable;
- (int)pid;
- (id)processState;
@end

@interface SBApplicationController : NSObject
+ (instancetype)sharedInstance;
- (SBApplication *)applicationWithBundleIdentifier:(NSString *)identifier;
- (NSArray *)allApplications;
@end

@interface SBApplicationInfo : NSObject
- (BOOL)wantsFullScreen;
- (BOOL)supportsMultiwindow;
- (BOOL)wantsExclusiveForeground;
@end

@interface SBAppLayout : NSObject
+ (id)homeScreenAppLayout;
- (id)rolesToLayoutItemsMap;
- (NSArray *)allItems;
- (id)centerItem;
- (id)floatingItem;
@end

@interface SBFluidSwitcherItemContainer : UIView
- (id)appLayout;
@end

@interface SBAppSwitcherPageView : UIView
- (id)appLayout;
@end

@interface SBMainSwitcherViewController : UIViewController
+ (instancetype)sharedInstance;
- (BOOL)_dismissSwitcherNoninteractivelyToAppLayout:(id)layout
                             dismissFloatingSwitcher:(BOOL)dismiss
                                          animated:(BOOL)animated;
@end

@interface SpringBoard : UIApplication
- (void)launchApplicationWithIdentifier:(NSString *)identifier suspended:(BOOL)suspended;
@end

@interface SBIconView : UIView
- (NSString *)applicationBundleIdentifier;
- (NSString *)applicationBundleIdentifierForShortcuts;
+ (void)activateShortcut:(id)item withBundleIdentifier:(NSString *)bundleID forIconView:(id)iconView;
@end

@interface SBSApplicationShortcutItem : NSObject
@property (nonatomic, copy) NSString *localizedTitle;
@property (nonatomic, copy) NSString *type;
@property (nonatomic, copy) NSString *bundleIdentifierToLaunch;
@end

#pragma mark - UIKit 私有

@interface _UISceneLayerHostContainerView : UIView
- (instancetype)initWithScene:(id)scene;
- (instancetype)initWithScene:(id)scene debugDescription:(id)desc;
- (id)_createHostViewForLayer:(id)layer;
- (id)scene;
@end

@interface UIView (SOPrivate)
- (id)_createHostViewForLayer:(id)layer;
@end

@interface UIWindow (SOPrivate)
- (void)_setSecure:(BOOL)secure;
@end

#pragma mark - LaunchServices（应用列表 / 图标）

@interface LSApplicationProxy : NSObject
@property (nonatomic, readonly) NSString *applicationIdentifier;
@property (nonatomic, readonly) NSString *localizedName;
@property (nonatomic, readonly) NSURL *bundleURL;
- (NSData *)iconDataForVariant:(int)variant;
@end

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (NSArray *)allInstalledApplications;
- (NSArray *)applicationsForUserActivityType:(NSString *)type;
@end

@interface UIImage (SOPrivate)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundleID
                                              format:(int)format
                                               scale:(CGFloat)scale;
@end

#pragma mark - 前向声明

@class SOWindowView;
@class SOOverlayWindow;
@class SOSceneHelper;
@class SOBackgrounderManager;
@class SOSplitPad;
