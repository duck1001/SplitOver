//
//  SOBackgrounderManager.h
//  SplitOver
//

#import "SOPrivate.h"

@interface SOBackgrounderManager : NSObject

@property (nonatomic, readonly) NSMutableArray<NSString *> *foregroundBundleIDs;
@property (nonatomic, readonly) NSMutableArray<NSString *> *foregroundSceneIDs;

+ (instancetype)sharedInstance;

- (void)setForeground:(NSString *)bundleID enabled:(BOOL)enabled;
- (BOOL)isForeground:(NSString *)bundleID;
- (void)setForegroundSceneID:(NSString *)sceneID enabled:(BOOL)enabled;
- (BOOL)isForegroundScene:(NSString *)sceneID;
- (BOOL)shouldKeepForeground:(FBScene *)scene;

@end
