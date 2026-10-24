# liquid_glass_shader

iOS-style liquid glass for Flutter, drawn by Flutter itself so iOS and Android look the same. With Impeller, glass refracts what is behind it through a fragment shader: the view bends toward the rim, splits into colours at the edge, and catches a thin line of light along the top. Without Impeller it falls back to a frosted blur, and under high contrast to an opaque surface.

It also ships `LiquidTabBar`, a tab bar that behaves like the iOS 26 one: press anywhere to lift a clear lens, drag it across the tabs, and let go to select.

<img src="https://raw.githubusercontent.com/YaserH25/liquid_glass_shader/main/doc/screenshots/tab_bar.png" width="300" alt="The liquid tab bar refracting a colourful page">

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

## Liquid tab bar

```dart
Scaffold(
  extendBody: true, // let the page scroll under the bar
  body: page,
  bottomNavigationBar: SafeArea(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: LiquidTabBar(
        tabCount: 4,
        selectedIndex: tab,
        onSelected: (index) => setState(() => tab = index),
        height: 64,
        tabBuilder: (context, index, active) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icons[index], color: active ? selectedColor : idleColor),
            Text(labels[index]),
          ],
        ),
      ),
    ),
  ),
)
```

- The bar calls `onSelected` on release, never while the finger is still down.
- Tabs are passive content. The bar handles touch and screen readers, so don't put an `InkWell`, `GestureDetector` or button semantics inside a tab: a tap would select twice. Each tab is a button for screen readers, with its selected state, labelled by the text your `tabBuilder` draws.
- A selection tick plays for each tab the lens crosses; turn it off with `haptics: false`.
- `LiquidTabBarStyle` holds the springs, lens size, magnification, stretch and rubber band if you want to tune the feel.
- `minimized: true` shrinks the bar into a pill at its start edge that shows only the current tab (draw it with `minimizedBuilder`), as iOS 26 does while a page scrolls down; a tap on the pill calls `onExpand`. The bar keeps its size, so set it from the page's scroll direction (a `NotificationListener<UserScrollNotification>` works) without the page moving. A screen reader always gets the full bar.

## Sharing the screen copy

Each piece of glass makes the engine copy the screen behind it, every frame, and that copy costs more than the shader's math. Glass that sets `shareBackdrop: true` (on `GlassSurface` or `LiquidTabBar`) reuses one copy per frame with other sharing glass under the same `GlassScope`.

A shared copy shows the screen as it was at the first sharing glass painted, so only share glass that is far apart, farther than its frost blurs (about three times the frost): a title bar at the top and a tab bar at the bottom, not a bar just above the tab bar, a sheet or glass over glass. Glass inside a page shares only while the page is current with nothing opening or closing over it, and half a second after it settles, so page transitions and closing sheets never show stale content. Shadows of glass always fall outside it, so a bar looks the same whether it shares or not.

## Theming

`GlassThemeData` holds the clear and frosted looks, the rim, edge hairline, the opaque fill used at the solid tier, and the lens tint and shadows. `GlassThemeData.light()` and `.dark()` are neutral starting points; pass your own to match your palette. A `GlassLook` sets `frost`, `tint`, the rim `band`, `bend`, `dispersion`, the `specular` highlight, `sheen` and `saturation`.

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

On an iPhone 17 Pro Max, scrolling a list under the tab bar and scrubbing the bar measured about 4.6 ms average raster time, with p99 under 7 ms, for clear glass, frosted glass and the blur tier alike.

The frost is the engine's blur followed by the shader: two passes. Avoid putting more filters in front of the glass; a fine full-resolution blur plus a colour-matrix pass made a bar lag on a current iPhone.

## Accessibility

- High contrast turns glass into an opaque surface.
- Reduced motion keeps the tab bar's lens flat and moves it from tab to tab at once.
- Screen readers tap each tab directly.

## Limitations

- Refraction uses one corner radius per surface: the smallest of its corners. The clip still rounds the rest, so a sheet with square bottom corners stays glass all the way down.
- Glass is for chrome over content. Refraction behind body text makes it harder to read.
- Inside the lifted lens, iOS tints everything with the selection colour; `LiquidTabBar` only draws the tab under the lens as current.

## License

MIT. See [LICENSE](LICENSE).
