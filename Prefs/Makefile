include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = SplitOverPrefs
SplitOverPrefs_FILES = SORootListController.m SOAppListController.m SOAppCell.m
SplitOverPrefs_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
SplitOverPrefs_FRAMEWORKS = UIKit Foundation
SplitOverPrefs_INSTALL_PATH = /Library/PreferenceBundles
SplitOverPrefs_PRIVATE_FRAMEWORKS = Preferences

include $(THEOS_MAKE_PATH)/bundle.mk
