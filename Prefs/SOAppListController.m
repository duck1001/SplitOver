//
//  SOAppListController.m
//  SplitOverPrefs — 选择圆盘里显示哪些 App
//

#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSTableCell.h>
#import <UIKit/UIKit.h>
#import <notify.h>

#define SO_PREFS_DOMAIN_STR "com.duck1001.splitover"

@interface SOAppCell : PSTableCell
@end

@interface SOAppListController : PSListController
@end

@implementation SOAppListController {
    NSArray *_cachedSpecs;
    NSArray<NSDictionary *> *_apps;
}

#pragma mark - 数据

- (NSArray<NSString *> *)selectedApps {
    CFPreferencesAppSynchronize(CFSTR(SO_PREFS_DOMAIN_STR));
    CFPropertyListRef value = CFPreferencesCopyAppValue(CFSTR("wheelApps"), CFSTR(SO_PREFS_DOMAIN_STR));
    NSArray *array = value ? (__bridge_transfer NSArray *)value : @[];
    NSMutableArray *valid = [NSMutableArray array];
    for (id item in array)
        if ([item isKindOfClass:[NSString class]]) [valid addObject:item];
    return valid;
}

- (void)setSelectedApps:(NSArray<NSString *> *)apps {
    CFPreferencesSetAppValue(CFSTR("wheelApps"), (__bridge CFArrayRef)apps, CFSTR(SO_PREFS_DOMAIN_STR));
    CFPreferencesAppSynchronize(CFSTR(SO_PREFS_DOMAIN_STR));
    notify_post("com.duck1001.splitover/prefsChanged");
}

- (NSArray<NSDictionary *> *)allApps {
    if (_apps) return _apps;

    NSMutableArray *result = [NSMutableArray array];
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    id workspace = [workspaceClass respondsToSelector:@selector(defaultWorkspace)]
        ? [workspaceClass performSelector:@selector(defaultWorkspace)] : nil;
    NSArray *proxies = [workspace respondsToSelector:@selector(allInstalledApplications)]
        ? [workspace performSelector:@selector(allInstalledApplications)] : @[];

    for (id proxy in proxies) {
        NSString *bundleID = [proxy respondsToSelector:@selector(applicationIdentifier)]
            ? [proxy performSelector:@selector(applicationIdentifier)] : nil;
        NSString *name = [proxy respondsToSelector:@selector(localizedName)]
            ? [proxy performSelector:@selector(localizedName)] : nil;
        if (!bundleID.length) continue;
        [result addObject:@{@"bid": bundleID, @"name": name.length ? name : bundleID}];
    }
    [result sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"name"] localizedCaseInsensitiveCompare:b[@"name"]];
    }];
    _apps = result;
    return result;
}

#pragma mark - 列表

- (PSSpecifier *)specifierForBundleID:(NSString *)bundleID name:(NSString *)name selected:(BOOL)selected {
    PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:name
                                                       target:self
                                                          set:nil
                                                          get:nil
                                                       detail:nil
                                                         cell:PSStaticTextCell
                                                         edit:nil];
    [spec setProperty:bundleID forKey:@"bid"];
    [spec setProperty:name forKey:@"appName"];
    [spec setProperty:@(selected) forKey:@"selected"];
    [spec setProperty:[SOAppCell class] forKey:@"cellClass"];
    return spec;
}

- (NSArray *)specifiers {
    if (_cachedSpecs) return _cachedSpecs;

    NSMutableArray *specs = [NSMutableArray array];
    NSArray<NSString *> *selected = [self selectedApps];

    PSSpecifier *selectedGroup = [PSSpecifier groupSpecifierWithName:@"圆盘顺序"];
    [selectedGroup setProperty:@"点按可移出；顺序就是圆盘从下往上的排列顺序。" forKey:@"footerText"];
    [specs addObject:selectedGroup];

    if (!selected.count) {
        [specs addObject:[PSSpecifier preferenceSpecifierNamed:@"还没有选择，默认显示常用 App"
                                                        target:nil set:nil get:nil detail:nil
                                                          cell:PSStaticTextCell edit:nil]];
    }
    for (NSString *bundleID in selected) {
        [specs addObject:[self specifierForBundleID:bundleID
                                               name:[self nameForBundleID:bundleID]
                                           selected:YES]];
    }

    [specs addObject:[PSSpecifier groupSpecifierWithName:@"全部 App"]];

    NSMutableSet *selectedSet = [NSMutableSet setWithArray:selected];
    for (NSDictionary *app in [self allApps]) {
        if ([selectedSet containsObject:app[@"bid"]]) continue;
        [specs addObject:[self specifierForBundleID:app[@"bid"] name:app[@"name"] selected:NO]];
    }

    _cachedSpecs = specs;
    return specs;
}

- (NSString *)nameForBundleID:(NSString *)bundleID {
    for (NSDictionary *app in [self allApps])
        if ([app[@"bid"] isEqualToString:bundleID]) return app[@"name"];
    return bundleID;
}

- (void)toggleApp:(PSSpecifier *)specifier {
    NSString *bundleID = [specifier propertyForKey:@"bid"];
    if (!bundleID.length) return;

    NSMutableArray *selected = [[self selectedApps] mutableCopy];
    if ([selected containsObject:bundleID]) {
        [selected removeObject:bundleID];
    } else {
        if (selected.count >= 8) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"最多 8 个"
                                                                           message:@"圆盘超过 8 个图标会挤在一起，先移出一个吧。"
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
            return;
        }
        [selected addObject:bundleID];
    }
    [self setSelectedApps:selected];

    _cachedSpecs = nil;
    [self reloadSpecifiers];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    PSSpecifier *spec = [self specifierAtIndexPath:indexPath];
    if ([spec propertyForKey:@"bid"]) {
        [self toggleApp:spec];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    [super tableView:tableView didSelectRowAtIndexPath:indexPath];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"圆盘里的 App";
}

@end
