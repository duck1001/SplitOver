//
//  SOAppCell.m
//  SplitOverPrefs
//

#import <Preferences/PSTableCell.h>
#import <UIKit/UIKit.h>

@interface UIImage (SOIcon)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundleID
                                              format:(int)format
                                               scale:(CGFloat)scale;
@end

@interface SOAppCell : PSTableCell
@end

@implementation SOAppCell

- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier {
    [super refreshCellContentsWithSpecifier:specifier];
    self.textLabel.text = [specifier propertyForKey:@"appName"] ?: @"";
    self.imageView.image = [self _iconFor:[specifier propertyForKey:@"bid"]];
    BOOL on = [[specifier propertyForKey:@"selected"] boolValue];
    self.accessoryType = on ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
}

- (UIImage *)_iconFor:(NSString *)bundleID {
    if (!bundleID.length) return nil;
    UIImage *image = nil;
    @try {
        image = [UIImage _applicationIconImageForBundleIdentifier:bundleID format:2 scale:0];
    } @catch (NSException *e) { image = nil; }
    return image;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat side = 29;
    self.imageView.frame = CGRectMake(15, (self.contentView.bounds.size.height - side) / 2.0, side, side);
    self.imageView.layer.cornerRadius = 6.5;
    self.imageView.layer.masksToBounds = YES;
    self.textLabel.frame = CGRectMake(54, 0,
                                      self.contentView.bounds.size.width - 90,
                                      self.contentView.bounds.size.height);
}

@end
