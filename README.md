# 26Safari  (by Seko)
iOS 26 "Liquid Glass" style bars for Safari on iOS 16 (Theos tweak, rootless).

## Build
Push this folder to a GitHub repo. The workflow in .github/workflows/build.yml builds it on
a macOS runner with real Theos and signs it with ldid. Download the `26safari-deb` artifact
from the Actions tab. (Or: `export THEOS=~/theos && make package` on a Mac/Linux with Theos.)

A real build is much larger than 16 KB and links UIKit and QuartzCore.

## What is hooked (all -layoutSubviews unless noted)
Pills (get the glass):      SFUnifiedTabBarItemView, SFCapsuleView, plus any ~44pt-tall view inside SFCapsuleCollectionView (REAL, seen in FLEX)
Containers (clear if pills exist, glass if not):
                            SFUnifiedTabBar, SFCapsuleNavigationBar, _SFCapsuleNavigationBar,
                            CapsuleNavigationBar, SFNavigationBar, _SFNavigationBar,
                            _SFBrowserNavigationBar, _SFCapsuleContainerView, NavigationBar
Toolbars (get the glass):   BrowserToolbar, _SFToolbar, any bottom-edge UIToolbar
Stock background (hidden):  SFNavigationBarBackgroundView
Controllers (log only):     BrowserController, SFBrowserController, _SFSearchController,
                            SafariReplayController   (-viewDidAppear:)
Press effect:               UIControl -setHighlighted: (bottom-bar buttons only)
Fallback (only if no named bar class exists): UIView -layoutSubviews, finds the bar by position

Classes that don't exist on your iOS are skipped silently.

## Debug
LG_DEBUG=1 (top of Tweak.xm) shows a red banner listing which classes were found and copies a
class check + view dump to the clipboard 9s after Safari starts. Set it to 0 when it works.
