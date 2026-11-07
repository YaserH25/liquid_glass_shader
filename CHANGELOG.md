## 0.3.1

* Much less GPU work, most of all on weak phones: the clear look's light frost is taken in the refraction shader, from sixteen reads spread like a Gaussian, instead of the engine's blur composed in front of it. The engine cannot tell where a shader filter reads, so that blur ran over the whole screen at full resolution every frame. Drawn by Impeller's software renderer, the default clear tab bar costs a quarter of what it did, and a held lens under a third, for a look within a pixel of the blur at an edge. Heavier frost, like the frosted look's, is still the engine's blur, which downsamples.
* The guard steps down after a single second in which most frames were late (`GlassGuard.severeShare`, 0.5 by default), instead of always waiting for two.
* The guard counts only frames in which glass drew a backdrop: a page covered by another, or glass under an `Offstage`, no longer loses its glass for jank elsewhere. Each tier is judged only by the frames drawn at it: the engine reports frame timings up to a second late, and frames from the tier before no longer count against the next. The scope stops watching frames once glass is solid or the guard is off.
* The tab bar's moving lens repaints in layers of its own: the glass, its tint, rim and backdrop, no longer repaints every frame the lens slides or follows a finger. At rest the tabs take no clip layer, and the lens fades by its colours (`GlassLens.opacity`) rather than through opacity layers, so lifting and dropping it costs no offscreen pass.
* Fixed: glass with `rim: false` drew a dark line round its lower half, and the lower rim did not fade with `strength`.
* CI runs the shader on Impeller (`flutter test --enable-impeller` in the example), which checks the frost against the engine's blur.

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
