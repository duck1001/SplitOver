//
//  SOBackgrounderManager.m
//  SplitOver
//

#import "SOBackgrounderManager.h"

@implementation SOBackgrounderManager

+ (instancetype)sharedInstance {
    static SOBackgrounderManager *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init {
    if ((self = [super init])) {
        _foregroundBundleIDs = [NSMutableArray array];
        _foregroundSceneIDs  = [NSMutableArray array];
    }
    return self;
}

- (void)setForeground:(NSString *)bundleID enabled:(BOOL)enabled {
    if (!bundleID) return;
    if (enabled) {
        if (![self.foregroundBundleIDs containsObject:bundleID])
            [self.foregroundBundleIDs addObject:bundleID];
    } else {
        [self.foregroundBundleIDs removeObject:bundleID];
    }
}

- (BOOL)isForeground:(NSString *)bundleID {
    return bundleID && [self.foregroundBundleIDs containsObject:bundleID];
}

- (void)setForegroundSceneID:(NSString *)sceneID enabled:(BOOL)enabled {
    if (!sceneID) return;
    if (enabled) {
        if (![self.foregroundSceneIDs containsObject:sceneID])
            [self.foregroundSceneIDs addObject:sceneID];
    } else {
        [self.foregroundSceneIDs removeObject:sceneID];
    }
}

- (BOOL)isForegroundScene:(NSString *)sceneID {
    return sceneID && [self.foregroundSceneIDs containsObject:sceneID];
}

- (BOOL)shouldKeepForeground:(FBScene *)scene {
    NSString *identifier = nil;
    if ([scene respondsToSelector:@selector(identifier)])
        identifier = [scene identifier];
    if (!identifier) identifier = SOGetIvar(scene, "_identifier");
    if (!identifier) return NO;

    for (NSString *bid in self.foregroundBundleIDs)
        if ([identifier containsString:bid]) return YES;
    for (NSString *sid in self.foregroundSceneIDs)
        if ([identifier isEqualToString:sid] || [identifier containsString:sid]) return YES;
    return NO;
}

@end
