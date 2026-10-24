# liquid_glass_shader

iOS-style liquid glass for Flutter, drawn by Flutter itself so iOS and Android look the same. With Impeller, glass refracts what is behind it through a fragment shader: the view bends toward the rim, splits into colours at the edge, and catches a thin line of light along the top. Without Impeller it falls back to a frosted blur, and under high contrast to an opaque surface.

It also ships `LiquidTabBar`, a tab bar that behaves like the iOS 26 one: press anywhere to lift a clear lens, drag it across the tabs, and let go to select. It hugs its tabs or fills its width, takes the sizes of iPhone, iPad and landscape bars, stands up as a column at the side of a screen, shrinks into a pill while a page scrolls, and works with a keyboard, a screen reader and right-to-left text.

<p>
  <img src="https://raw.githubusercontent.com/YaserH25/liquid_glass_shader/main/doc/screenshots/tab_bar.png" width="260" alt="The liquid tab bar refracting a colourful page under the example's controls">
  <img src="https://raw.githubusercontent.com/YaserH25/liquid_glass_shader/main/doc/screenshots/tab_bar_drag.gif" width="420" alt="A finger dragging the lens from Home to Profile and back to Search">
</p>

## How it works

`GlassBackdrop` pushes a backdrop filter layer whose filter is `shaders/liquid_glass.frag`. For each pixel inside the glass's rounded rectangle, the shader measures the distance to the edge, follows a dome profile across the rim band, and samples the backdrop displaced inward along the edge normal. Near the rim it samples red and blue at slightly different offsets (dispersion), it can magnify the whole interior, and it raises saturation so what shows through looks vivid. Pixels outside the glass return at once, so the cost stays with the glass's own area. Pixels in the flat middle, farther than the rim band from the edge, take one backdrop read and the saturation and skip the rest. Near the rim the edge direction comes from the rounded rectangle's gradient in closed form, not from extra distance evaluations.

The shader places the glass by where its box actually is on screen, so scaling, transforms and RTL all line up. When an ancestor moves the glass without repainting it (a page transition sliding a bar), the glass notices after the frame and repaints.

## Requirements

- Flutter 3.47 or newer.
- Refraction needs Impeller: iOS, and Android with Vulkan or OpenGL ES. Skia, web and widget tests get the blur tier; nothing to configure.

## Quick start

```dart
import 'package:liquid_glass_shader/liquid_glass_shader.dart';

// Any chrome that floats over content.
GlassSurface(
  borderRadius: BorderRadius.circular(28),
  padding: const EdgeInsets.all(16),
  child: const Text('On glass'),
)
```

A `GlassScope` is optional. Without one, glass is clear and follows the app's brightness: the Material or Cupertino theme's, or else the platform's. Add one near the root to choose the style, theme or performance guard for everything below it:

```dart
GlassScope(
  style: GlassStyle.frosted,      // or GlassStyle.clear
  theme: GlassThemeData.light(),  // or your own colours
  child: MyHomePage(),
)
```

A surface can insist on a style (`style: GlassStyle.frosted` for text sitting right on the glass) or take a custom `GlassLook`. `strength` from 0 to 1 fades all of the glass in, which suits a title bar that collapses as the page scrolls.

`GlassSurface` and `LiquidTabBar` put their content on a transparent `Material`, so ink from buttons and list tiles shows on the glass. That `Material` also sets the text style below it to the Material body style, so in a Cupertino or plain `WidgetsApp` give text inside the glass the style you want.

## The example

The example app is a playground: one colourful page under the bar, with a glass card of controls for the layout, hugging or filling, 3 to 5 tabs, labels, clear or frosted glass, LTR or RTL (with Arabic labels), the theme, minimize on scroll, the tick and a tinted lens. Every picture here comes from it.

```bash
cd example && flutter run
```

## Liquid tab bar

```dart
Stack(
  children: [
    page, // scrolls under the bar
    Positioned(
      left: 21,
      right: 21,
      bottom: 21,
      child: LiquidTabBar(
        tabCount: 4,
        selectedIndex: tab,
        onSelected: (index) => setState(() => tab = index),
        tabBuilder: (context, index, active) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icons[index], color: active ? selectedColor : idleColor),
            Text(labels[index]),
          ],
        ),
      ),
    ),
  ],
)
```

It works as `Scaffold.bottomNavigationBar` too (with `extendBody: true` so the page scrolls under it).

- The bar calls `onSelected` on release, never while the finger is still down. A change of `selectedIndex` from elsewhere slides the lens there.
- Tabs are passive content. The bar handles touch, the keyboard and screen readers, so don't put an `InkWell`, `GestureDetector` or button semantics inside a tab: a tap would select twice. Each tab is a button for screen readers, with its selected state, labelled by the text your `tabBuilder` draws (or an icon's `semanticLabel`).
- A tab is laid out at its own size, centred in its slot, and scaled down when it does not fit, so a long label or large text is never cut short. Give it a size of its own: no `Expanded` inside.

### Sizes and presets

`LiquidTabBarMetrics` holds every size. Its presets carry the sizes of the system tab bar on iOS 27, measured on the simulators, because Apple publishes none:

| Preset | Thickness | Tab length | Where iOS uses it |
| --- | --- | --- | --- |
| `LiquidTabBarMetrics.stacked` (default) | 62 | 90 | iPhone upright: icon above label |
| `LiquidTabBarMetrics.inline` | 46 | 74 | iPad: icon beside label, along the top |
| `LiquidTabBarMetrics.compactInline` | 44 | 78 | iPhone sideways: the smallest bar |
| `LiquidTabBarMetrics.vertical` | 48 | 51 | iPhone Duo cover screen: a column at the side |

A preset only sets sizes; draw the tabs to match in `tabBuilder`.

```dart
LiquidTabBar(
  metrics: LiquidTabBarMetrics.compactInline.copyWith(
    thickness: 40,                         // the whole bar, glass included
    tabExtent: double.infinity,            // fill the width instead of hugging
    inset: 3,                              // glass edge to tabs
    lensGap: const EdgeInsets.symmetric(horizontal: 4), // lens narrower than its slot
    borderRadius: BorderRadius.circular(14), // none makes a capsule
    minimizedSize: 44,                     // none makes the pill as thick as the bar
  ),
  alignment: AlignmentDirectional.centerStart, // where hugging glass sits
  // ...
)
```

- `thickness` is the whole bar across, glass included: its height along the bottom of a screen. Keep it at 44 or more so tabs stay easy to hit.
- `tabExtent` is the longest a tab's slot gets. Like iOS, the glass hugs its tabs at that length and sits where `alignment` says, centred by default, but it is never longer than its space: four 90-long tabs fill an iPhone's width, three hug the middle. `double.infinity` always fills.
- The bar takes the whole width it is given and `thickness` of height, whatever the glass inside does, so the page under it never moves. Touches beside the glass reach the page.

<p>
  <img src="https://raw.githubusercontent.com/YaserH25/liquid_glass_shader/main/doc/screenshots/tab_bar_landscape.png" width="520" alt="A compact inline bar on an iPhone held sideways">
  <img src="https://raw.githubusercontent.com/YaserH25/liquid_glass_shader/main/doc/screenshots/tab_bar_ipad.png" width="400" alt="An inline bar along the top of an iPad">
</p>

### A vertical bar at the side

`axis: Axis.vertical` stands the bar up as a column, as the iPhone Duo's cover screen does with its tab bar. The lens, the jelly, the rubber band and minimizing all follow the axis; a vertical bar runs from the top in either text direction, as Apple's does, and the arrow keys become up and down.

```dart
LiquidTabBar(
  axis: Axis.vertical,
  metrics: LiquidTabBarMetrics.vertical,
  alignment: Alignment.bottomCenter, // Apple's column sits at the bottom
  // ...
)
```

<img src="https://raw.githubusercontent.com/YaserH25/liquid_glass_shader/main/doc/screenshots/tab_bar_duo.png" width="300" alt="A vertical bar in the side column of the iPhone Duo's cover screen">

### Where to put it: adaptive placement

Where the bar sits on the screen, and when to give way to a sidebar or rail, is the app's choice: Apple and Material both decide it by size class, and Flutter has no size class for a package to read. The example's [`AdaptiveTabBarLayout`](example/lib/adaptive_tab_bar_layout.dart) is a short recipe to copy. It picks what iOS 27 does:

- a screen that keeps a column at one side for its bars (the iPhone Duo's cover screen, found by its one-sided side inset): `vertical`, standing in that column;
- a short screen, like an iPhone held sideways: `compactInline` along the bottom;
- a tablet or an unfolded phone, at least 600 both ways: `inline` along the top;
- anything else, like an iPhone held upright: `stacked` along the bottom.

```dart
final layout = AdaptiveTabBarLayout.of(context);
LiquidTabBar(
  axis: layout.axis,
  metrics: layout.metrics,
  minimized: layout.minimizes && scrolledDown, // only along the bottom
  // ...
)
```

### Minimize on scroll

`minimized: true` shrinks the bar into a pill that shows only the current tab (draw it with `minimizedBuilder`), as iOS does on iPhone while a page scrolls down; a tap on the pill, or Enter on it, calls `onExpand`. The bar keeps its size, so set it from the page's scroll direction without the page moving. A screen reader always gets the full bar. The pill sits where `minimizedAlignment` says: by default at the bottom of the start edge, or at the top of a vertical bar.

```dart
NotificationListener<UserScrollNotification>(
  onNotification: (n) {
    final down = n.direction == ScrollDirection.reverse;
    if (n.direction != ScrollDirection.idle && down != minimized) {
      setState(() => minimized = down);
    }
    return false;
  },
  child: page,
)
```

<p>
  <img src="https://raw.githubusercontent.com/YaserH25/liquid_glass_shader/main/doc/screenshots/tab_bar_minimize.gif" width="300" alt="The bar shrinking into its pill as the page scrolls down, and growing back">
  <img src="https://raw.githubusercontent.com/YaserH25/liquid_glass_shader/main/doc/screenshots/tab_bar_minimized.png" width="220" alt="The minimized pill at the start edge">
</p>

Apple supports minimizing on iPhone only; a bar along the top of an iPad stays put.

### Glass and lens

The bar's glass takes the same settings as `GlassSurface`: `style` (force clear or frosted), `look`, `rim`, `edge`, `strength` and `shadows`. `LiquidTabBarLens` sets the lens: its tint and its resting and lifted shadows (falling back to the `GlassScope` theme), the ring it draws under keyboard focus, and its size, magnification and optics once lifted.

```dart
LiquidTabBar(
  style: GlassStyle.frosted,
  shadows: const [BoxShadow(color: Color(0x29000000), blurRadius: 24, offset: Offset(0, 8))],
  lens: LiquidTabBarLens(
    tint: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
    magnification: 1.25,
    liftedExtent: 1.25,
  ),
  // ...
)
```

<p>
  <img src="https://raw.githubusercontent.com/YaserH25/liquid_glass_shader/main/doc/screenshots/tab_bar_lifted.png" width="220" alt="The lens lifted under a finger, clear and magnifying">
  <img src="https://raw.githubusercontent.com/YaserH25/liquid_glass_shader/main/doc/screenshots/tab_bar_frosted.png" width="220" alt="The bar in frosted glass">
  <img src="https://raw.githubusercontent.com/YaserH25/liquid_glass_shader/main/doc/screenshots/tab_bar_dark.png" width="220" alt="The bar in dark mode">
</p>

### Motion and the tick

`LiquidTabBarMotion` holds the springs and the feel: how the lens settles, lifts, drops and wobbles (the jelly), how fast it catches up with the finger, how far it stretches with speed, the rubber band past the ends, and how much the bar swells while pressed. The defaults match the iOS 26 tab bar, measured frame by frame.

```dart
LiquidTabBar(
  motion: LiquidTabBarMotion.standard.copyWith(
    maxStretch: 0.2,  // a firmer drop
    rubberBand: 0.1,
  ),
  onTick: (tab) => HapticFeedback.lightImpact(), // or null for none
  // ...
)
```

`onTick` hears each tab the lens moves onto, as a finger drags it or a key or screen reader selects; it plays the selection click by default (`LiquidTabBar.selectionClick`).

### Keyboard, screen readers and right to left

- With a keyboard (a tablet, a desktop, the web) the bar is one focus stop, as a tab list is: the arrows along the bar select the tab beside the current one on screen, Home and End jump to the ends, and a ring circles the lens while the focus came from the keyboard.
- Screen readers reach each tab as a button and tap it directly.
- Reduced motion keeps the lens flat and moves it from tab to tab at once, and minimizes at once.
- High contrast turns the glass into an opaque surface.
- In right-to-left text the tabs run from the right and the arrows follow the screen.

<img src="https://raw.githubusercontent.com/YaserH25/liquid_glass_shader/main/doc/screenshots/tab_bar_rtl.png" width="220" alt="The bar in right-to-left with Arabic labels">

### Foldables

When a hinge, or a fold that is half open like a book, crosses the bar, the glass lays itself out on one side of it, so no tab sits on the crease: the side its alignment points to, or the larger side for a centred bar. Flat folds are left alone. The bar reads `MediaQuery.displayFeatures`, which Flutter fills on Android today; iOS will follow once Flutter reports the iPhone Duo's fold, with no change here.

<img src="https://raw.githubusercontent.com/YaserH25/liquid_glass_shader/main/doc/screenshots/tab_bar_android_fold.png" width="360" alt="An unfolded Pixel 10 Pro Fold with an inline bar along the top">

## Sharing the screen copy

Each piece of glass makes the engine copy the screen behind it, every frame, and that copy costs more than the shader's math. Glass that sets `shareBackdrop: true` (on `GlassSurface` or `LiquidTabBar`) reuses one copy per frame with other sharing glass under the same `GlassScope`.

A shared copy shows the screen as it was at the first sharing glass painted, so only share glass that is far apart, farther than its frost blurs (about three times the frost): a title bar at the top and a tab bar at the bottom, not a bar just above the tab bar, a sheet or glass over glass. Glass inside a page shares only while the page is current with nothing opening or closing over it, and half a second after it settles, so page transitions and closing sheets never show stale content. Shadows of glass always fall outside it, so a bar looks the same whether it shares or not.

## Theming

`GlassThemeData` holds the clear and frosted looks, the rim, edge hairline, the opaque fill used at the solid tier, and the lens tint and shadows. `GlassThemeData.light()` and `.dark()` are neutral starting points; pass your own to match your palette. A `GlassLook` sets `frost`, `tint`, the rim `band`, `bend`, `dispersion`, the `specular` highlight, `sheen` and `saturation`. A single tab bar can override the lens colours with `LiquidTabBarLens`.

## Performance

Glass draws at one of three tiers (`GlassQuality`): refraction, blur, or solid. While glass is on screen, `GlassScope` watches each frame's raster time and how late it lands (on iPhone the GPU's work never shows in raster time, so a GPU that cannot keep up shows only as frames landing late). Gaps after the app was idle are not judged, and gaps are measured against the window's usual gap, so a display that runs slower than it reports (Low Power Mode) does not look slow. After two windows of one second of drawing in a row in which more than 10% of the frames were late, it steps down one tier for the rest of the session. Windows are time, not frame counts, so a weak phone that draws only a few frames a second steps down as fast as any other: on the Android emulator with software rendering (about 5 fps, OpenGL ES), glass went from refraction to blur to solid within about two seconds of scrolling. Tune or switch this off with `GlassGuard`.

The scope stores nothing. To keep a slow phone from stuttering again on every launch, save the tier it reports and start from it next time:

```dart
GlassScope(
  initialCap: savedCap, // read from your storage once, at startup
  onCapChanged: (cap) => save(cap),
  child: child,
)
```

Consider letting the saved tier expire (after a week, say), so a phone that had one slow day, or got an update, gets its glass back.

The tab bar builds its glass once per change of state, never per frame: while the lens slides, lifts or stretches, only the lens rebuilds, and the swell and the shrink into the pill run as transitions. On an iPhone 17 Pro Max at 120 Hz, with the example's frame-time test (`example/integration_test/tab_bar_perf_test.dart`, in profile mode), a page scrolling under the bar, a finger scrubbing it and the lens sliding between tabs averaged 0.35 to 0.49 ms of UI build time and 1.2 to 1.5 ms of raster time a frame, and no frame missed its budget.

The frost is the engine's blur followed by the shader: two passes. Avoid putting more filters in front of the glass; a fine full-resolution blur plus a colour-matrix pass made a bar lag on a current iPhone.

## Limitations

- Refraction uses one corner radius per surface: the smallest of its corners. The clip still rounds the rest, so a sheet with square bottom corners stays glass all the way down.
- Glass is for chrome over content. Refraction behind body text makes it harder to read.
- Inside the lifted lens, iOS tints everything with the selection colour; `LiquidTabBar` only draws the tab under the lens as current.
- Tabs share the bar's length equally; iOS sizes each tab to its label.
- Folds reach the bar only where Flutter reports them: on Android today. On the Android emulator's Pixel 10 Pro Fold (API 36 image), apps received no fold even half open, so the fold above is shown flat; the stepping aside is covered by tests.

## Migrating from 0.2

- `height` and `inset` move into `metrics: LiquidTabBarMetrics(...)`, and `thickness` is the whole bar, glass included: `height: 64` with the default inset of 4 is `thickness: 72`.
- The bar now hugs its tabs like iOS. Pass `tabExtent: double.infinity` to fill the width as before.
- `style: LiquidTabBarStyle(...)` splits into `motion: LiquidTabBarMotion(...)` (the springs, `catchUp`, `pressedScale`, `stretchPerSpeed`, `maxStretch`, `speedSmoothing`, `rubberBand`) and `lens: LiquidTabBarLens(...)`, where `liftedWidth` and `liftedHeight` become `liftedExtent` and `liftedThickness`, and `lensBand`, `lensBend`, `lensDispersion` and `lensSpecular` become `band`, `bend`, `dispersion` and `specular`. `style` on the bar now forces clear or frosted glass, as on `GlassSurface`.
- `minimizedSize` moves to `LiquidTabBarMetrics`, and defaults to the bar's thickness.
- `haptics: false` becomes `onTick: null`.

## License

MIT. See [LICENSE](LICENSE).
