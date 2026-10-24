## 0.3.0

Breaking: see "Migrating from 0.2" in the README.

* Sizes: `LiquidTabBarMetrics` holds the thickness (the whole bar, glass included), the longest a tab gets, the inset, a gap around the resting lens, the corner radius and the pill's size, with presets carrying the iOS 27 tab bar's measured sizes: `stacked` (iPhone upright), `inline` (iPad), `compactInline` (iPhone sideways, the smallest) and `vertical` (iPhone Duo).
* As on iOS, the glass hugs its tabs and sits by `alignment`, filling its width only when there is no room; `tabExtent: double.infinity` always fills. `minimizedAlignment` places the pill.
* `axis: Axis.vertical` stands the bar up as a column at the side of the screen, as on the iPhone Duo's cover screen.
* `LiquidTabBarStyle` splits into `LiquidTabBarMotion` (springs and feel) and `LiquidTabBarLens` (the lens's tint, shadows, focus ring, lifted size and optics, per bar). The bar takes `style`, `look`, `rim`, `edge` and `strength` like `GlassSurface`; `GlassLens` takes a tint and shadows of its own.
* `onTick` replaces `haptics`: it hears each tab the lens moves onto, and plays the selection click by default.
* The keyboard: the bar is one focus stop, with the arrows, Home and End selecting tabs, Enter expanding the pill, and a focus ring round the lens.
* Tabs are laid out at their own size and scaled down to fit their slot, so a long label or large text is never cut short or overflows.
* The glass keeps to one side of a hinge or half-open fold across the bar (`MediaQuery.displayFeatures`, Android today).
* Faster: while the lens moves, swells or the bar minimizes, only the lens rebuilds, never the glass.
* The example is now a playground for every setting, with `AdaptiveTabBarLayout`, a recipe that places the bar as iOS 27 does on iPhone, iPad and the iPhone Duo, and a profile-mode frame-time test. The README shows each feature with screenshots.

## 0.2.0

* `LiquidTabBar` can shrink into a pill at its start edge that shows only the current tab, as the iOS 26 tab bar does while a page scrolls down: `minimized`, `onExpand` and `minimizedBuilder`, with `LiquidTabBarStyle.minimize` and `minimizedSize`. The bar keeps its size, so the page under it does not move; touches beside the pill reach the page. A screen reader always gets the full bar, and reduced motion shrinks it at once.

## 0.1.0

* First release: `GlassSurface`, `GlassBackdrop` and the refraction shader, `GlassScope` with quality tiers, a frame-time guard, and `initialCap` / `onCapChanged` to remember the tier between launches, `GlassThemeData` and `GlassLook`, `GlassLens`, and `LiquidTabBar`.
