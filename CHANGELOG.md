## 0.2.0

* `LiquidTabBar` can shrink into a pill at its start edge that shows only the current tab, as the iOS 26 tab bar does while a page scrolls down: `minimized`, `onExpand` and `minimizedBuilder`, with `LiquidTabBarStyle.minimize` and `minimizedSize`. The bar keeps its size, so the page under it does not move; touches beside the pill reach the page. A screen reader always gets the full bar, and reduced motion shrinks it at once.

## 0.1.0

* First release: `GlassSurface`, `GlassBackdrop` and the refraction shader, `GlassScope` with quality tiers, a frame-time guard, and `initialCap` / `onCapChanged` to remember the tier between launches, `GlassThemeData` and `GlassLook`, `GlassLens`, and `LiquidTabBar`.
