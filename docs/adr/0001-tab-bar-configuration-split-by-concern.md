# Tab bar configuration is split by concern, with no theme

`LiquidTabBar` takes its sizes (`LiquidTabBarMetrics`), its motion (`LiquidTabBarMotion`) and its lens's look (`LiquidTabBarLens`) as three separate immutable values, plus the bar's own glass as the same flat parameters `GlassSurface` takes. The metrics presets (`stacked`, `inline`, `compactInline`, `vertical`) carry sizes measured on the iOS 27 simulators, because Apple publishes no tab bar sizes. There is no tab bar theme: an app has one tab bar, so a theme would only be a second way to set the same values, and colours already come from `GlassScope`.

## Considered Options

- One style object, as 0.2's `LiquidTabBarStyle` was: it mixed springs, optics and the pill's size, and "style" already means clear or frosted glass in this package.
- A theme like Material's `NavigationBarTheme`, with widget parameters overriding it: rejected for the reason above.
