#
#  SplitOver — 悬浮窗 + 圆盘分屏
#  iOS 15.0 – 16.x, rootless（Dopamine / palera1n rootless）
#  需要 roothide：把 THEOS_PACKAGE_SCHEME 改成 roothide 并在 LDFLAGS 加 -lroothide
#

export ARCHS = arm64 arm64e
export TARGET = iphone:clang:15.6:15.0
SCHEME ?= roothide
export THEOS_PACKAGE_SCHEME = $(SCHEME)
export PACKAGE_VERSION = 1.0.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SplitOver
SplitOver_FILES = Tweak.x \
	SOSettings.m \
	SOBackgrounderManager.m \
	SOSceneHelper.m \
	SOOverlayWindow.m \
	SOWindowView.m \
	SOWindowManager.m \
	SOWheelController.m \
	SOGestureController.m \
	SOAppHelper.m \
	SOSceneHost.m
SplitOver_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-function
SplitOver_FRAMEWORKS = UIKit CoreGraphics QuartzCore CoreFoundation Foundation
SplitOver_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += Prefs
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "killall -9 SpringBoard"
