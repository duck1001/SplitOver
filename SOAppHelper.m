//
//  SOAppHelper.m
//  SplitOver
//

#import "SOAppHelper.h"
#import "SOSettings.h"
#import "SOOverlayWindow.h"

@implementation SOAppInfo
@end

@implementation SOAppHelper

+ (NSArray<SOAppInfo *> *)installedApps {
    static NSArray<SOAppInfo *> *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableArray *result = [NSMutableArray array];
        Class wsClass = NSClassFromString(@"LSApplicationWorkspace");
        id workspace = [wsClass respondsToSelector:@selector(defaultWorkspace)]
            ? [wsClass performSelector:@selector(defaultWorkspace)] : nil;
        NSArray *proxies = [workspace respondsToSelector:@selector(allInstalledApplications)]
            ? [workspace performSelector:@selector(allInstalledApplications)] : @[];

        for (id proxy in proxies) {
            NSString *bid = nil;
            NSString *name = nil;
            if ([proxy respondsToSelector:@selector(applicationIdentifier)])
                bid = [proxy performSelector:@selector(applicationIdentifier)];
            if ([proxy respondsToSelector:@selector(localizedName)])
                name = [proxy performSelector:@selector(localizedName)];
            if (!bid.length) continue;
            if ([bid hasPrefix:@"com.apple.WebKit"] || [bid hasPrefix:@"com.apple.SafariViewService"])
                continue;

            SOAppInfo *info = [SOAppInfo new];
            info.bundleID = bid;
            info.name = name.length ? name : bid;
            [result addObject:info];
        }

        [result sortUsingComparator:^NSComparisonResult(SOAppInfo *a, SOAppInfo *b) {
            return [a.name localizedCaseInsensitiveCompare:b.name];
        }];
        cache = result;
    });
    return cache;
}

+ (SOAppInfo *)appForBundleID:(NSString *)bundleID {
    if (!bundleID) return nil;
    for (SOAppInfo *info in [self installedApps])
        if ([info.bundleID isEqualToString:bundleID]) return info;
    return nil;
}

+ (NSString *)displayNameForBundleID:(NSString *)bundleID {
    NSString *name = [self appForBundleID:bundleID].name;
    if (name.length) return name;

    Class sbCtrl = NSClassFromString(@"SBApplicationController");
    if (sbCtrl) {
        id app = [[sbCtrl performSelector:@selector(sharedInstance)]
                  performSelector:@selector(applicationWithBundleIdentifier:) withObject:bundleID];
        if ([app respondsToSelector:@selector(displayName)]) {
            NSString *n = [app performSelector:@selector(displayName)];
            if (n.length) return n;
        }
    }
    return bundleID;
}

+ (UIImage *)iconForBundleID:(NSString *)bundleID size:(CGFloat)size {
    if (!bundleID) return nil;
    UIImage *image = nil;
    @try {
        image = [UIImage _applicationIconImageForBundleIdentifier:bundleID format:2 scale:0];
    } @catch (NSException *e) { image = nil; }

    if (!image) {
        Class wsClass = NSClassFromString(@"LSApplicationWorkspace");
        id workspace = [wsClass respondsToSelector:@selector(defaultWorkspace)]
            ? [wsClass performSelector:@selector(defaultWorkspace)] : nil;
        if ([workspace respondsToSelector:@selector(allInstalledApplications)]) {
            for (id proxy in [workspace performSelector:@selector(allInstalledApplications)]) {
                NSString *bid = [proxy respondsToSelector:@selector(applicationIdentifier)]
                    ? [proxy performSelector:@selector(applicationIdentifier)] : nil;
                if (![bid isEqualToString:bundleID]) continue;
                if ([proxy respondsToSelector:@selector(iconDataForVariant:)]) {
                    NSData *data = [proxy performSelector:@selector(iconDataForVariant:) withObject:@(2)];
                    if (data) image = [UIImage imageWithData:data];
                }
                break;
            }
        }
    }
    return image;
}

+ (NSString *)foregroundBundleID {
    Class sbCtrl = NSClassFromString(@"SBApplicationController");
    if (!sbCtrl || ![sbCtrl respondsToSelector:@selector(sharedInstance)]) return nil;
    id controller = [sbCtrl performSelector:@selector(sharedInstance)];
    if (![controller respondsToSelector:@selector(allApplications)]) return nil;

    for (id app in [controller performSelector:@selector(allApplications)]) {
        NSString *bid = [app respondsToSelector:@selector(bundleIdentifier)]
            ? [app performSelector:@selector(bundleIdentifier)] : nil;
        if (!bid.length) continue;
        if ([SOOverlayWindow isWindowed:bid]) continue;

        id state = [app respondsToSelector:@selector(processState)]
            ? [app performSelector:@selector(processState)] : nil;
        if (state && [state respondsToSelector:@selector(isForeground)] &&
            [state performSelector:@selector(isForeground)])
            return bid;
    }
    return nil;
}

+ (BOOL)isAppRunning:(NSString *)bundleID {
    if (!bundleID) return NO;
    Class sbCtrl = NSClassFromString(@"SBApplicationController");
    if (!sbCtrl) return NO;
    id app = [[sbCtrl performSelector:@selector(sharedInstance)]
              performSelector:@selector(applicationWithBundleIdentifier:) withObject:bundleID];
    id state = [app respondsToSelector:@selector(processState)]
        ? [app performSelector:@selector(processState)] : nil;
    if (state && [state respondsToSelector:@selector(isRunning)])
        return [state performSelector:@selector(isRunning)];
    return app != nil;
}

+ (NSArray<NSString *> *)wheelFallbackApps {
    NSMutableArray *apps = [NSMutableArray array];
    for (SOAppInfo *info in [self installedApps]) {
        if ([info.bundleID hasPrefix:@"com.apple."] &&
            ![info.bundleID isEqualToString:@"com.apple.mobilesafari"] &&
            ![info.bundleID isEqualToString:@"com.apple.MobileSMS"] &&
            ![info.bundleID isEqualToString:@"com.apple.mobilemail"] &&
            ![info.bundleID isEqualToString:@"com.apple.MobileAddressBook"] &&
            ![info.bundleID isEqualToString:@"com.apple.camera"] &&
            ![info.bundleID isEqualToString:@"com.apple.mobileslideshow"] &&
            ![info.bundleID isEqualToString:@"com.apple.notes"] &&
            ![info.bundleID isEqualToString:@"com.apple.reminders"] &&
            ![info.bundleID isEqualToString:@"com.apple.Maps"] &&
            ![info.bundleID isEqualToString:@"com.apple.mobiletimer"] &&
            ![info.bundleID isEqualToString:@"com.apple.calculator"] &&
            ![info.bundleID isEqualToString:@"com.apple.Preferences"])
            continue;
        [apps addObject:info.bundleID];
        if (apps.count >= 6) break;
    }
    return apps;
}

@end
