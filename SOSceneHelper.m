//
//  SOSceneHelper.m
//  SplitOver
//
//  场景查找与画面挂载：沿用 MilkyWayReborn 的六段兜底策略，
//  去掉 iOS 26 专用路径，保留 15/16 可用的全部入口。
//

#import "SOSceneHelper.h"
#import "SOSettings.h"

@implementation SOSceneHelper

#pragma mark - Scene manager

+ (id)sceneManager {
    Class mainWS = NSClassFromString(@"SBMainWorkspace");
    if (mainWS && [mainWS respondsToSelector:@selector(sharedInstance)]) {
        id workspace = [mainWS sharedInstance];
        if ([workspace respondsToSelector:@selector(sceneManager)]) {
            id mgr = [workspace performSelector:@selector(sceneManager)];
            if (mgr) return mgr;
        }
    }
    Class fbMgr = NSClassFromString(@"FBSceneManager");
    if (fbMgr && [fbMgr respondsToSelector:@selector(sharedInstance)])
        return [fbMgr sharedInstance];
    return nil;
}

#pragma mark - Scene lookup

+ (FBScene *)sceneForBundleID:(NSString *)bundleID {
    return [self sceneForBundleID:bundleID sceneID:nil];
}

+ (FBScene *)sceneForBundleID:(NSString *)bundleID sceneID:(NSString *)sceneID {
    if (!bundleID && !sceneID) return nil;
    id manager = [self sceneManager];
    if (!manager) return nil;

    NSMutableArray<NSString *> *needles = [NSMutableArray array];
    if (sceneID) [needles addObject:sceneID];
    if (bundleID) [needles addObject:bundleID];

    for (NSString *needle in needles) {
        FBScene *scene = [self _lookup:needle manager:manager];
        if (scene) return scene;
    }
    return nil;
}

+ (FBScene *)_lookup:(NSString *)needle manager:(id)manager {
    // 1. manager 上的场景字典
    for (NSString *ivarName in @[@"_scenesByID", @"_scenes"]) {
        id dict = SOGetIvar(manager, ivarName.UTF8String);
        if ([dict isKindOfClass:[NSDictionary class]]) {
            FBScene *s = [self _findScene:needle inDict:dict];
            if (s) return s;
        }
    }

    // 2. iOS 15/16：SBSceneManager._workspace 下的字典
    id workspace = SOGetIvar(manager, "_workspace");
    if (workspace) {
        for (NSString *ivarName in @[@"_allScenesByID", @"_scenesByIdentifier", @"_scenesByID"]) {
            id dict = SOGetIvar(workspace, ivarName.UTF8String);
            if ([dict isKindOfClass:[NSDictionary class]]) {
                FBScene *s = [self _findScene:needle inDict:dict];
                if (s) return s;
            }
        }
    }

    // 3. 场景句柄映射
    for (NSString *ivarName in @[@"_persistentMapSceneIdentityToSceneHandle",
                                  @"_transientMapSceneIdentityToSceneHandle"]) {
        id map = SOGetIvar(manager, ivarName.UTF8String);
        if ([map respondsToSelector:@selector(allValues)]) {
            for (id handle in [map allValues]) {
                NSString *sid = nil;
                if ([handle respondsToSelector:@selector(sceneIdentifier)])
                    sid = [handle performSelector:@selector(sceneIdentifier)];
                if (sid && [sid containsString:needle] &&
                    [handle respondsToSelector:@selector(scene)]) {
                    id scene = [handle performSelector:@selector(scene)];
                    if (scene) return scene;
                }
            }
        }
    }

    // 4. allScenes
    if ([manager respondsToSelector:@selector(allScenes)]) {
        for (id scene in [manager performSelector:@selector(allScenes)]) {
            if ([scene respondsToSelector:@selector(identifier)]) {
                NSString *sid = [scene identifier];
                if (sid && [sid containsString:needle]) return scene;
            }
        }
    }

    // 5. 深扫 ivar：任何 key 命中的字典值都试一遍
    unsigned int count = 0;
    Ivar *ivars = class_copyIvarList(object_getClass(manager), &count);
    for (unsigned int i = 0; i < count; i++) {
        const char *type = ivar_getTypeEncoding(ivars[i]);
        if (!type || type[0] != '@') continue;
        id value = SOGetIvar(manager, ivar_getName(ivars[i]));
        if (![value isKindOfClass:[NSDictionary class]]) continue;
        for (NSString *key in (NSDictionary *)value) {
            if (![key isKindOfClass:[NSString class]]) continue;
            if (![key containsString:needle]) continue;
            id candidate = ((NSDictionary *)value)[key];
            if ([candidate respondsToSelector:@selector(layerManager)] ||
                [candidate respondsToSelector:@selector(identifier)]) {
                free(ivars);
                return candidate;
            }
            if ([candidate respondsToSelector:@selector(scene)]) {
                id scene = [candidate performSelector:@selector(scene)];
                if (scene) { free(ivars); return scene; }
            }
        }
    }
    if (ivars) free(ivars);

    // 6. SBSceneManager 类方法
    Class sbSceneMgr = NSClassFromString(@"SBSceneManager");
    Class identityProvider = NSClassFromString(@"SBSceneIdentityProvider");
    if (sbSceneMgr && identityProvider &&
        [sbSceneMgr respondsToSelector:@selector(existingSceneHandleForSceneIdentity:)] &&
        [identityProvider respondsToSelector:@selector(identityForIdentifier:)]) {
        id identity = [identityProvider performSelector:@selector(identityForIdentifier:) withObject:needle];
        if (identity) {
            id handle = [sbSceneMgr performSelector:@selector(existingSceneHandleForSceneIdentity:) withObject:identity];
            if (handle && [handle respondsToSelector:@selector(scene)]) {
                id scene = [handle performSelector:@selector(scene)];
                if (scene) return scene;
            }
        }
    }
    return nil;
}

+ (FBScene *)_findScene:(NSString *)needle inDict:(NSDictionary *)dict {
    if (![dict count]) return nil;
    id direct = dict[needle];
    if (direct) return direct;
    for (NSString *key in dict) {
        if (![key isKindOfClass:[NSString class]]) continue;
        if ([key containsString:needle]) return dict[key];
    }
    return nil;
}

#pragma mark - 画面挂载

+ (UIView *)createLayerHostViewForScene:(FBScene *)scene {
    if (!scene) return nil;
    Class containerClass = NSClassFromString(@"_UISceneLayerHostContainerView");
    if (!containerClass) return nil;

    _UISceneLayerHostContainerView *container = nil;
    if ([containerClass instancesRespondToSelector:@selector(initWithScene:debugDescription:)])
        container = [[containerClass alloc] initWithScene:scene debugDescription:@"SplitOver"];
    else if ([containerClass instancesRespondToSelector:@selector(initWithScene:)])
        container = [[containerClass alloc] initWithScene:scene];
    if (!container) return nil;

    // iOS 15/16 需要手工把每层 host view 建出来；iOS 16.4+ 的 init 会自己建
    if ([scene respondsToSelector:@selector(layerManager)]) {
        id layerManager = [scene layerManager];
        NSArray *layers = [layerManager respondsToSelector:@selector(layers)] ? [layerManager layers] : nil;
        if ([layers count] && [container respondsToSelector:@selector(_createHostViewForLayer:)]) {
            for (id layer in layers) {
                UIView *hostView = [container _createHostViewForLayer:layer];
                if (hostView) {
                    hostView.frame = container.bounds;
                    hostView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                    [container addSubview:hostView];
                }
            }
        }
    }
    container.frame = [UIScreen mainScreen].bounds;
    return container;
}

#pragma mark - 前台化

+ (void)setScene:(FBScene *)scene foreground:(BOOL)foreground {
    if (!scene) return;
    @try {
        if ([scene respondsToSelector:@selector(settings)] &&
            [scene respondsToSelector:@selector(updateSettings:withTransitionContext:)]) {
            id settings = [scene settings];
            id mutable = [settings respondsToSelector:@selector(mutableCopy)] ? [settings mutableCopy] : nil;
            if (mutable && [mutable respondsToSelector:@selector(setForeground:)]) {
                [mutable setForeground:foreground];
                [scene updateSettings:mutable withTransitionContext:nil];
                return;
            }
        }
        id mutable = SOGetIvar(scene, "_mutableSettings");
        if (mutable) {
            SOSetIvarBool(mutable, "_foreground", foreground);
            if ([scene respondsToSelector:@selector(updateSettings:withTransitionContext:completion:)])
                [scene updateSettings:mutable withTransitionContext:nil completion:nil];
        }
    } @catch (NSException *e) {
        NSLog(@"[SplitOver] setScene foreground exception: %@", e);
    }
}

+ (void)wakeSceneForBundleID:(NSString *)bundleID {
    [self setScene:[self sceneForBundleID:bundleID] foreground:YES];
}

#pragma mark - Keep-alive

static NSMutableDictionary<NSString *, dispatch_source_t> *_keepAlive = nil;

+ (void)startKeepAliveForBundleID:(NSString *)bundleID {
    if (!bundleID || !SOSettings.shared.keepAlive) return;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ _keepAlive = [NSMutableDictionary new]; });

    [self stopKeepAliveForBundleID:bundleID];

    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(timer, dispatch_walltime(NULL, 0), NSEC_PER_SEC, 100 * NSEC_PER_MSEC);
    dispatch_source_set_event_handler(timer, ^{
        FBScene *scene = [SOSceneHelper sceneForBundleID:bundleID];
        if (scene) [SOSceneHelper setScene:scene foreground:YES];
    });
    dispatch_resume(timer);
    _keepAlive[bundleID] = timer;
}

+ (void)stopKeepAliveForBundleID:(NSString *)bundleID {
    if (!bundleID || !_keepAlive) return;
    dispatch_source_t timer = _keepAlive[bundleID];
    if (timer) {
        dispatch_source_cancel(timer);
        [_keepAlive removeObjectForKey:bundleID];
    }
}

+ (void)stopAllKeepAlive {
    for (NSString *key in [_keepAlive allKeys])
        [self stopKeepAliveForBundleID:key];
}

@end
