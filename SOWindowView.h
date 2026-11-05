//
//  SOWindowView.h
//  SplitOver — 单个应用窗口
//

#import "SOPrivate.h"

typedef NS_ENUM(NSInteger, SOSnap) {
    SOSnapFree = 0,
    SOSnapFull,
    SOSnapLeft,
    SOSnapRight,
    SOSnapTop,
    SOSnapBottom,
    SOSnapTopLeft,
    SOSnapTopRight,
    SOSnapBottomLeft,
    SOSnapBottomRight,
};

@interface SOWindowView : UIView

@property (nonatomic, copy) NSString *bundleID;
@property (nonatomic, copy) NSString *sceneID;
@property (nonatomic, strong) id sceneHost;   // SOSceneHost
@property (nonatomic, assign) SOSnap snap;
@property (nonatomic, assign) BOOL isOpen;

@property (nonatomic, copy) void (^onClose)(SOWindowView *window);
@property (nonatomic, copy) void (^onFocus)(SOWindowView *window);
@property (nonatomic, copy) void (^onSnapRequest)(SOWindowView *window, SOSnap snap);

- (instancetype)initWithContentView:(UIView *)contentView
                           bundleID:(NSString *)bundleID
                              scene:(FBScene *)scene;

- (void)updateLayers;
- (void)relayoutContent;
- (void)setTitleText:(NSString *)title icon:(UIImage *)icon;

@end
