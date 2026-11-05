# SplitOver

悬浮窗分屏 · iOS 15.0 – 16.x · rootless / roothide

左下角或右下角上滑呼出圆盘 → 滑动选中 App → 松手，选中的 App 以半边悬浮窗的形式盖在当前 App 上。
正在用的 App（快手、B 站、游戏）继续在底下播放，不需要重新打开，也不要求它有分屏能力。

---

## 交互

| 操作 | 结果 |
|---|---|
| 左下 / 右下角向上滑 | 圆盘从角落展开，图标沿 90° 弧线排列 |
| 手指滑动 | 高亮跟随角度变化，触感反馈，中心显示 App 名 |
| 松手 | 选中的 App 从图标位置长出来（0.42s 弹簧动画），贴到对应半边 |
| 点一下角落 | 圆盘常驻，点图标同样生效（适合单手） |
| 三指上滑 / 状态栏双击 / Home 条长按 | 备用呼出方式，可在设置里单独关 |
| 窗口标题栏拖动 | 移动窗口；拖到屏幕左/右边缘 64pt 内出现蓝色吸附预览，松手贴半屏 |
| 窗口左右下角拖动 | 双向调大小（左下手柄改变原点，右下手柄改变尺寸） |
| 窗口底边中间点一下 | 关闭这个悬浮窗（只收窗口，不杀进程） |
| 标题栏长按 | 全屏 / 左半 / 右半 / 左上 / 右上 / 自由 / 关闭 |

分屏时窗口从状态栏下方开始，**顶部留出状态栏区域，通知中心照常下拉**；系统横幅通知在窗口之上。

## 设置

`设置 → SplitOver`（PreferenceLoader）：

- 总开关、圆盘开关
- 圆盘 App 列表（最多 8 个，勾选顺序 = 从下往上的排序）
- 边缘灵敏度、窗口间隙、圆角、不透明度
- 手势开关：角落上滑 / 三指上滑 / 状态栏双击 / Home 条长按
- 后台保活、强制多窗口能力

改完即时生效（Darwin 通知 → SpringBoard 内重挂手势，不用 Respring）。

## 实现结构

```
SplitOver/
├── Tweak.x                  SpringBoard 钩子：注入入口、后台卡片长按、图标快捷菜单、
│                            deactivation 拦截、场景层刷新
├── SOSettings.*             CFPreferences + Darwin 通知
├── SOPrivate.h              私有 API 声明（FBScene / SBApplication / RBSAssertion / LSApplication）
├── SOSceneHelper.*          FBScene 六段兜底查找 + _UISceneLayerHostContainerView 挂载 + keep-alive
├── SOBackgrounderManager.*  托管 App 的前台状态登记
├── SOOverlayWindow.*        触摸穿透宿主窗口 + 左下/右下角热区 + 键盘独立窗口
├── SOWindowView.*           单个悬浮窗：标题栏、拖动、三角操作区、画面等比缩放
├── SOWindowManager.*        窗口注册表、吸附几何、出场/关闭动画、圆盘调用入口
├── SOWheelController.*      角部圆盘：弧线布局、角度选中、挥出/收起动画
├── SOGestureController.*    角部上滑 + 全局手势
├── SOAppHelper.*            应用列表、图标、前台 App 判定
├── Prefs/                   PreferenceBundle：Root.plist + 圆盘 App 选择器
└── .github/workflows/build.yml
```

### 画面是怎么来的

`SOSceneHelper` 从 `SBMainWorkspace` / `FBSceneManager` 里按六种策略捞出目标 App 的 `FBScene`，
再用 `_UISceneLayerHostContainerView` 把场景层挂到普通 `UIView` 上。
App 进程用 `launchApplicationWithIdentifier:suspended:YES` 拉起（不进前台），
配合 `RBSAssertion`（PreventTaskSuspend）+ 每秒一次的前台状态刷新 + `deactivationReasons` 拦截，
保证被托管的 App 在后台持续渲染。

非缩放模式下，App 按整屏分辨率渲染，再等比缩进窗口；设置里勾选的 scale App 会改成直接按窗口尺寸下发 scene frame。

## 构建

需要 macOS + Theos（`$THEOS`）：

```bash
make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless ARCHS="arm64 arm64e" TARGET=iphone:clang:16.5:15.0
```

产物：`packages/com.duck1001.splitover_1.0.0_iphoneos-arm64.deb`

RootHide 构建：把 `THEOS_PACKAGE_SCHEME` 改成 `roothide`，并在 `SplitOver_LDFLAGS` 加 `-lroothide`。

CI：push 到 `main` 自动在 `macos-15` 上跑 Theos 打包，artifact 名 `SplitOver-deb`。

## 已知边界

- 只支持 iOS 15 – 16（rootless / roothide）。iOS 17+ 的 `FBScene` 体系不同，`_UISceneHostingActivationStateHostComponent` 那条路径没接。
- 被托管的 App 必须是已安装且能后台启动的普通 App；系统级 daemon、需要 CarPlay/扩展的场景不适用。
- 部分 App（银行、DRM 视频）检测到非全屏 scene 会黑屏，这是它们自己的保护，不是挂载失败。
- 同一 App 同时只保留一个窗口；窗口总数上限 4。
