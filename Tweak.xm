// 26Safari by Seko - iOS 26 "Liquid Glass" style bars for Safari on iOS 16
//
// Real Liquid Glass (refraction / lensing) can't be done with public UIKit on iOS 16.
// This approximates it: ultra-thin blur + tint + top sheen + inner edge glow +
// specular rim + soft shadow + floating pill shape + spring "press" on buttons.

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#define LG_DEBUG 1   // set to 0 to remove the red banner and the clipboard dump

static const NSInteger kLGTag = 0x4C471A55;

// =====================  THE GLASS VIEW  =====================

@interface LGGlass : UIView
@property (nonatomic, assign) CGFloat radius;
@end

@implementation LGGlass {
    UIVisualEffectView *_blur;
    UIView *_tint;
    CAGradientLayer *_sheen;
    CALayer *_innerHost;
    CAShapeLayer *_inner;
    CAShapeLayer *_innerMask;
    CAGradientLayer *_rim;
    CAShapeLayer *_rimMask;
}
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.userInteractionEnabled = NO;
        self.layer.shadowColor = UIColor.blackColor.CGColor;
        self.layer.shadowOpacity = 0.20;
        self.layer.shadowRadius = 14;
        self.layer.shadowOffset = CGSizeMake(0, 6);

        _blur = [[UIVisualEffectView alloc] initWithEffect:
                 [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial]];
        _blur.clipsToBounds = YES;
        [self addSubview:_blur];

        _tint = [UIView new];
        _tint.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
            return t.userInterfaceStyle == UIUserInterfaceStyleDark
                ? [UIColor colorWithWhite:1 alpha:0.06]
                : [UIColor colorWithWhite:1 alpha:0.28];
        }];
        [_blur.contentView addSubview:_tint];

        // top sheen
        _sheen = [CAGradientLayer layer];
        _sheen.colors = @[(id)[UIColor colorWithWhite:1 alpha:0.30].CGColor,
                          (id)[UIColor colorWithWhite:1 alpha:0.0].CGColor];
        _sheen.startPoint = CGPointMake(0.5, 0);
        _sheen.endPoint = CGPointMake(0.5, 0.6);
        [_blur.contentView.layer addSublayer:_sheen];

        // inner edge glow (gives the "thick glass" edge)
        _innerHost = [CALayer layer];
        _innerMask = [CAShapeLayer layer];
        _innerHost.mask = _innerMask;
        _inner = [CAShapeLayer layer];
        _inner.fillColor = UIColor.blackColor.CGColor;
        _inner.fillRule = kCAFillRuleEvenOdd;
        _inner.shadowColor = UIColor.whiteColor.CGColor;
        _inner.shadowOpacity = 0.45;
        _inner.shadowRadius = 5;
        _inner.shadowOffset = CGSizeMake(0, 1.5);
        [_innerHost addSublayer:_inner];
        [_blur.contentView.layer addSublayer:_innerHost];

        // specular rim
        _rim = [CAGradientLayer layer];
        _rim.colors = @[(id)[UIColor colorWithWhite:1 alpha:0.95].CGColor,
                        (id)[UIColor colorWithWhite:1 alpha:0.05].CGColor,
                        (id)[UIColor colorWithWhite:1 alpha:0.05].CGColor,
                        (id)[UIColor colorWithWhite:1 alpha:0.70].CGColor];
        _rim.locations = @[@0, @0.35, @0.65, @1];
        _rim.startPoint = CGPointMake(0, 0);
        _rim.endPoint = CGPointMake(1, 1);
        _rimMask = [CAShapeLayer layer];
        _rimMask.fillColor = nil;
        _rimMask.strokeColor = UIColor.blackColor.CGColor;
        _rimMask.lineWidth = 1.2;
        _rim.mask = _rimMask;
        [self.layer addSublayer:_rim];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect b = self.bounds;
    CGFloat r = MIN(self.radius, MIN(b.size.width, b.size.height) / 2);
    _blur.frame = b;
    _blur.layer.cornerRadius = r;
    _tint.frame = b;
    _sheen.frame = b;

    _innerHost.frame = b;
    _innerMask.frame = _innerHost.bounds;
    _innerMask.path = [UIBezierPath bezierPathWithRoundedRect:b cornerRadius:r].CGPath;
    _inner.frame = _innerHost.bounds;
    UIBezierPath *ring = [UIBezierPath bezierPathWithRect:CGRectInset(b, -40, -40)];
    [ring appendPath:[UIBezierPath bezierPathWithRoundedRect:b cornerRadius:r]];
    ring.usesEvenOddFillRule = YES;
    _inner.path = ring.CGPath;

    _rim.frame = b;
    _rimMask.path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(b, 0.6, 0.6) cornerRadius:r].CGPath;
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:b cornerRadius:r].CGPath;
}
@end

// =====================  HELPERS  =====================

static NSMutableSet<NSString *> *gMatched;     // views found by the geometry fallback
static NSMutableSet<NSString *> *gSeen;        // controllers that fired a hook
static BOOL gPillMode = NO;                    // pill classes exist -> glass goes on the pills
static BOOL gGeometryOn = NO;                  // fallback active

// hide the stock bar backgrounds / stock blur (a few levels deep), never our own glass
static void LGHideBackgrounds(UIView *v, int depth) {
    if (depth > 4) return;
    for (UIView *s in v.subviews) {
        if (s.tag == kLGTag) continue;
        NSString *n = NSStringFromClass(s.class);
        if ([n containsString:@"BarBackground"] || [n containsString:@"Backdrop"] ||
            [s isKindOfClass:UIVisualEffectView.class]) {
            s.hidden = YES;
            s.alpha = 0;
            continue;
        }
        LGHideBackgrounds(s, depth + 1);
    }
}

static void LGInstall(UIView *bar, UIEdgeInsets inset, CGFloat radius) {
    LGGlass *g = (LGGlass *)[bar viewWithTag:kLGTag];
    if (!g) {
        g = [[LGGlass alloc] initWithFrame:bar.bounds];
        g.tag = kLGTag;
        [bar insertSubview:g atIndex:0];
    }
    g.radius = radius;
    g.frame = UIEdgeInsetsInsetRect(bar.bounds, inset);
    [bar sendSubviewToBack:g];
    bar.backgroundColor = UIColor.clearColor;
    bar.clipsToBounds = NO;
    LGHideBackgrounds(bar, 0);
}

// container classes: if pills exist, only make the container see-through; otherwise it gets glass
static void LGContainer(UIView *v, UIEdgeInsets inset, CGFloat radius) {
    if (gPillMode) {
        v.backgroundColor = UIColor.clearColor;
        LGHideBackgrounds(v, 0);
    } else {
        LGInstall(v, inset, radius);
    }
}

// glass on every pill-shaped view (about 44pt tall) inside a container, whatever its class is
static void LGPillsIn(UIView *root, int depth) {
    if (depth > 3) return;
    for (UIView *s in root.subviews) {
        if (s.tag == kLGTag || s.hidden) continue;
        CGSize z = s.bounds.size;
        if (z.height >= 36 && z.height <= 64 && z.width >= 100) {
            if (!gMatched) gMatched = [NSMutableSet set];
            [gMatched addObject:NSStringFromClass(s.class)];
            LGInstall(s, UIEdgeInsetsZero, 25);
        } else {
            LGPillsIn(s, depth + 1);
        }
    }
}

static BOOL LGGeomMatch(UIView *v) {
    UIWindow *w = v.window;
    if (!w) return NO;
    CGRect b = v.bounds;
    if (b.size.width < 300 || b.size.height < 40 || b.size.height > 240) return NO;
    CGRect r = [v convertRect:b toView:w];
    return CGRectGetMaxY(r) >= w.bounds.size.height - 2 &&
           r.size.width >= w.bounds.size.width - 2;
}

static BOOL LGSkipClass(NSString *n) {
    return [n hasPrefix:@"WK"] || [n containsString:@"Background"] ||
           [n containsString:@"Backdrop"] || [n containsString:@"Effect"] ||
           [n containsString:@"ContentView"] || [n containsString:@"Layout"] ||
           [n hasPrefix:@"UITransition"] || [n isEqualToString:@"UIWindow"] ||
           [n isEqualToString:@"LGGlass"];
}

static void LGDump(UIView *v, UIWindow *w, int depth, NSMutableString *out) {
    CGRect r = [v convertRect:v.bounds toView:w];
    if (CGRectGetMaxY(r) < w.bounds.size.height - 260) return;
    NSString *n = NSStringFromClass(v.class);
    NSString *sup = NSStringFromClass(class_getSuperclass(v.class));
    [out appendFormat:@"%*s%@ : %@ %@ hidden=%d\n", depth * 2, "", n, sup,
        NSStringFromCGRect(r), v.hidden];
    if ([n hasPrefix:@"WK"] || depth > 12) return;
    for (UIView *s in v.subviews) LGDump(s, w, depth + 1, out);
}

// =====================  EVERY CLASS NAME WE'VE COLLECTED  =====================
// Declared so Logos can hook them. A class that doesn't exist on your iOS is simply skipped.

// pills (the visible address / tab capsules)
@interface SFUnifiedTabBarItemView : UIView @end
@interface SFCapsuleView : UIView @end
@interface SFCapsuleCollectionView : UIView @end                 // REAL (seen in FLEX)
@interface CapsuleNavigationBarViewController : UIViewController @end   // REAL (seen in FLEX)
// bars / containers around the pills
@interface SFUnifiedTabBar : UIView @end
@interface SFCapsuleNavigationBar : UIView @end
@interface _SFCapsuleNavigationBar : UIView @end
@interface CapsuleNavigationBar : UIView @end
@interface SFNavigationBar : UIView @end
@interface _SFNavigationBar : UIView @end
@interface _SFBrowserNavigationBar : UIView @end
@interface _SFCapsuleContainerView : UIView @end
@interface NavigationBar : UIView @end
// bottom button toolbar
@interface BrowserToolbar : UIView @end
@interface _SFToolbar : UIView @end
// stock background
@interface SFNavigationBarBackgroundView : UIView @end
// controllers (log only)
@interface BrowserController : UIViewController @end
@interface SFBrowserController : UIViewController @end
@interface _SFSearchController : UIViewController @end
@interface SafariReplayController : UIViewController @end

static NSArray<NSString *> *LGAllNames(void) {
    return @[@"SFCapsuleCollectionView", @"CapsuleNavigationBarViewController",
             @"SFUnifiedTabBarItemView", @"SFCapsuleView", @"_SFCapsuleView",
             @"SFUnifiedTabBar", @"SFCapsuleNavigationBar", @"_SFCapsuleNavigationBar",
             @"CapsuleNavigationBar", @"SFNavigationBar", @"_SFNavigationBar",
             @"_SFBrowserNavigationBar", @"_SFCapsuleContainerView", @"SFCapsuleContainerView",
             @"NavigationBar", @"BrowserToolbar", @"_SFToolbar",
             @"SFNavigationBarBackgroundView", @"BrowserController", @"SFBrowserController",
             @"_SFSearchController", @"SafariReplayController", @"BrowserRootViewController",
             @"_SFSearchField", @"TabDocumentView", @"_UIToolbarContentView",
             @"_UIVisualEffectBackdropView"];
}

static BOOL LGExists(NSString *n) { return NSClassFromString(n) != nil; }

static NSString *LGClassReport(void) {
    NSMutableString *s = [NSMutableString stringWithString:@"CLASS CHECK\n"];
    for (NSString *n in LGAllNames()) {
        Class c = NSClassFromString(n);
        if (!c) { [s appendFormat:@"  %@: MISSING\n", n]; continue; }
        NSMutableString *chain = [NSMutableString string];
        for (Class k = class_getSuperclass(c); k; k = class_getSuperclass(k))
            [chain appendFormat:@" > %@", NSStringFromClass(k)];
        [s appendFormat:@"  %@: found%@\n", n, chain];
    }
    Class cv = NSClassFromString(@"SFCapsuleView");
    if (cv) {
        [s appendFormat:@"  SFCapsuleView responds: _updateVisualEffectView=%d cornerRadius=%d\n",
            (int)[cv instancesRespondToSelector:NSSelectorFromString(@"_updateVisualEffectView")],
            (int)[cv instancesRespondToSelector:NSSelectorFromString(@"cornerRadius")]];
    }
    [s appendFormat:@"PILL MODE: %d  GEOMETRY FALLBACK: %d\nCONTROLLERS THAT FIRED: %@\n",
        gPillMode, gGeometryOn, gSeen ? [gSeen allObjects] : @[]];
    return s;
}

// =====================  HOOKS  =====================

// ---- Pills: these get the glass ----
%group Pills

%hook SFUnifiedTabBarItemView
- (void)layoutSubviews {
    %orig;
    LGInstall((UIView *)self, UIEdgeInsetsMake(0, 0, 0, 0), 25);
}
%end

%hook SFCapsuleView
- (void)layoutSubviews {
    %orig;
    LGInstall((UIView *)self, UIEdgeInsetsMake(0, 0, 0, 0), 25);
}
%end

%end // Pills

// ---- Containers: see-through if pills exist, glass otherwise ----
%group Containers

// REAL class (confirmed with FLEX): full-screen container that holds the tab pills.
// It gets no glass itself; the pill-sized views inside it do.
%hook SFCapsuleCollectionView
- (void)layoutSubviews {
    %orig;
    UIView *v = (UIView *)self;
    v.backgroundColor = UIColor.clearColor;
    LGHideBackgrounds(v, 0);
    LGPillsIn(v, 0);
}
%end

%hook SFUnifiedTabBar
- (void)layoutSubviews {
    %orig;
    LGContainer((UIView *)self, UIEdgeInsetsMake(0, 4, 0, 4), 25);
}
%end

%hook SFCapsuleNavigationBar
- (void)layoutSubviews {
    %orig;
    LGContainer((UIView *)self, UIEdgeInsetsMake(0, 4, 0, 4), 25);
}
%end

%hook _SFCapsuleNavigationBar
- (void)layoutSubviews {
    %orig;
    LGContainer((UIView *)self, UIEdgeInsetsMake(0, 4, 0, 4), 25);
}
%end

%hook CapsuleNavigationBar
- (void)layoutSubviews {
    %orig;
    LGContainer((UIView *)self, UIEdgeInsetsMake(0, 4, 0, 4), 25);
}
%end

%hook SFNavigationBar
- (void)layoutSubviews {
    %orig;
    LGContainer((UIView *)self, UIEdgeInsetsMake(0, 4, 0, 4), 25);
}
%end

%hook _SFNavigationBar
- (void)layoutSubviews {
    %orig;
    LGContainer((UIView *)self, UIEdgeInsetsMake(0, 4, 0, 4), 25);
}
%end

%hook _SFBrowserNavigationBar
- (void)layoutSubviews {
    %orig;
    LGContainer((UIView *)self, UIEdgeInsetsMake(0, 4, 0, 4), 25);
}
%end

%hook _SFCapsuleContainerView
- (void)layoutSubviews {
    %orig;
    LGContainer((UIView *)self, UIEdgeInsetsMake(0, 4, 0, 4), 25);
}
%end

%hook NavigationBar
- (void)layoutSubviews {
    %orig;
    LGContainer((UIView *)self, UIEdgeInsetsMake(0, 4, 0, 4), 25);
}
%end

%end // Containers

// ---- Bottom toolbar (back / forward / share / bookmarks / tabs): glass ----
%group Toolbars

%hook BrowserToolbar
- (void)layoutSubviews {
    %orig;
    LGInstall((UIView *)self, UIEdgeInsetsMake(2, 10, 2, 10), 24);
}
%end

%hook _SFToolbar
- (void)layoutSubviews {
    %orig;
    LGInstall((UIView *)self, UIEdgeInsetsMake(2, 10, 2, 10), 24);
}
%end

// any UIToolbar that sits at the bottom edge of the window
%hook UIToolbar
- (void)layoutSubviews {
    %orig;
    UIView *v = (UIView *)self;
    if (LGGeomMatch(v)) LGInstall(v, UIEdgeInsetsMake(2, 10, 2, 10), 24);
}
%end

%end // Toolbars

// ---- Stock background: hide it ----
%group Backgrounds

%hook SFNavigationBarBackgroundView
- (void)layoutSubviews {
    %orig;
    UIView *v = (UIView *)self;
    v.alpha = 0;
    v.hidden = YES;
}
%end

%end // Backgrounds

// ---- Controllers: log only (they have no visuals to restyle) ----
%group Controllers

%hook CapsuleNavigationBarViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (!gSeen) gSeen = [NSMutableSet set];
    [gSeen addObject:@"CapsuleNavigationBarViewController"];
}
%end

%hook BrowserController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (!gSeen) gSeen = [NSMutableSet set];
    [gSeen addObject:@"BrowserController"];
}
%end

%hook SFBrowserController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (!gSeen) gSeen = [NSMutableSet set];
    [gSeen addObject:@"SFBrowserController"];
}
%end

%hook _SFSearchController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (!gSeen) gSeen = [NSMutableSet set];
    [gSeen addObject:@"_SFSearchController"];
}
%end

%hook SafariReplayController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (!gSeen) gSeen = [NSMutableSet set];
    [gSeen addObject:@"SafariReplayController"];
}
%end

%end // Controllers

// ---- Press effect: toolbar buttons spring up when touched (like iOS 26) ----
%group Touch

%hook UIControl
- (void)setHighlighted:(BOOL)h {
    %orig;
    UIView *v = (UIView *)self;
    UIWindow *w = v.window;
    if (!w || v.bounds.size.width > 120 || v.bounds.size.width < 20) return;
    CGRect r = [v convertRect:v.bounds toView:w];
    if (CGRectGetMinY(r) < w.bounds.size.height - 200) return;   // bottom bar only
    [UIView animateWithDuration:(h ? 0.18 : 0.45)
                          delay:0
         usingSpringWithDamping:(h ? 0.8 : 0.5)
          initialSpringVelocity:0
                        options:(UIViewAnimationOptionAllowUserInteraction |
                                 UIViewAnimationOptionBeginFromCurrentState)
                     animations:^{
        v.transform = h ? CGAffineTransformMakeScale(1.18, 1.18) : CGAffineTransformIdentity;
    } completion:nil];
}
%end

%end // Touch

// ---- Fallback: finds the bottom bar by position. Only used if NO named bar class exists. ----
%group Geometry

%hook UIView
- (void)layoutSubviews {
    %orig;
    UIView *v = (UIView *)self;
    if (v.bounds.size.width < 300 || v.tag == kLGTag) return;
    NSString *n = NSStringFromClass(v.class);
    if (LGSkipClass(n) || !LGGeomMatch(v)) return;
    for (UIView *a = v.superview; a && ![a isKindOfClass:UIWindow.class]; a = a.superview) {
        if (!LGSkipClass(NSStringFromClass(a.class)) && LGGeomMatch(a)) return;
    }
    if (!gMatched) gMatched = [NSMutableSet set];
    [gMatched addObject:n];
    BOOL tall = v.bounds.size.height > 100;
    LGInstall(v, tall ? UIEdgeInsetsMake(6, 10, 6, 10) : UIEdgeInsetsMake(2, 10, 2, 10),
              tall ? 30 : 24);
}
%end

%end // Geometry

// =====================  DEBUG (red banner + clipboard dump)  =====================

#if LG_DEBUG
static UILabel *gStatus;

static UIWindow *LGKeyWindow(void) {
    for (UIWindow *w in UIApplication.sharedApplication.windows)
        if (w.isKeyWindow) return w;
    return UIApplication.sharedApplication.windows.firstObject;
}

static void LGShowStatus(void) {
    UIWindow *w = LGKeyWindow();
    if (!w) return;
    if (!gStatus) {
        gStatus = [UILabel new];
        gStatus.font = [UIFont boldSystemFontOfSize:10];
        gStatus.textColor = UIColor.whiteColor;
        gStatus.backgroundColor = [UIColor colorWithRed:0.8 green:0 blue:0 alpha:0.92];
        gStatus.textAlignment = NSTextAlignmentCenter;
        gStatus.numberOfLines = 5;
        gStatus.adjustsFontSizeToFitWidth = YES;
        gStatus.userInteractionEnabled = NO;
    }
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *n in LGAllNames()) if (LGExists(n)) [found addObject:n];
    gStatus.text = [NSString stringWithFormat:
        @"26Safari v2.0 LOADED\nclasses found (%lu): %@\npill mode: %d  geometry fallback: %d\npill views styled: %@",
        (unsigned long)found.count,
        found.count ? [found componentsJoinedByString:@","] : @"none",
        gPillMode, gGeometryOn,
        gMatched.count ? [[gMatched allObjects] componentsJoinedByString:@","] : @""];
    gStatus.frame = CGRectMake(0, w.safeAreaInsets.top + 2, w.bounds.size.width, 72);
    if (gStatus.superview != w) [w addSubview:gStatus];
    [w bringSubviewToFront:gStatus];
}
#endif

// =====================  START  =====================

%ctor {
    NSLog(@"[26Safari] loaded in %@", NSBundle.mainBundle.bundleIdentifier);

    // Wait 2s so SafariServices is definitely loaded, then install the hooks.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        gPillMode = LGExists(@"SFUnifiedTabBarItemView") || LGExists(@"SFCapsuleView") ||
                    LGExists(@"SFCapsuleCollectionView");
        BOOL anyBar = gPillMode || LGExists(@"CapsuleNavigationBarViewController") || LGExists(@"BrowserToolbar") || LGExists(@"_SFToolbar") ||
            LGExists(@"SFUnifiedTabBar") || LGExists(@"SFCapsuleNavigationBar") ||
            LGExists(@"_SFCapsuleNavigationBar") || LGExists(@"CapsuleNavigationBar") ||
            LGExists(@"SFNavigationBar") || LGExists(@"_SFNavigationBar") ||
            LGExists(@"_SFBrowserNavigationBar") || LGExists(@"_SFCapsuleContainerView");

        %init(Pills);
        %init(Containers);
        %init(Toolbars);
        %init(Backgrounds);
        %init(Controllers);
        %init(Touch);
        if (!anyBar) {
            gGeometryOn = YES;
            %init(Geometry);
        }
#if LG_DEBUG
        LGShowStatus();
#endif
    });

#if LG_DEBUG
    for (NSNumber *t in @[@4, @7, @12]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, t.intValue * NSEC_PER_SEC),
                       dispatch_get_main_queue(), ^{ LGShowStatus(); });
    }
    // 9s after launch: copy class check + view dump to the clipboard
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 9 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        NSMutableString *out = [NSMutableString stringWithString:LGClassReport()];
        [out appendFormat:@"GEOMETRY-MATCHED BARS: %@\n\nVIEW DUMP\n", gMatched ? [gMatched allObjects] : @[]];
        for (UIWindow *w in UIApplication.sharedApplication.windows) {
            [out appendFormat:@"WINDOW %@ %@\n", NSStringFromClass(w.class), NSStringFromCGRect(w.frame)];
            LGDump(w, w, 1, out);
        }
        [UIPasteboard generalPasteboard].string = out;
        NSLog(@"[26Safari] dump:\n%@", out);
    });
#endif
}
