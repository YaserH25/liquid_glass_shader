# liquid_glass_shader example

A playground for `LiquidTabBar`: a colourful scrolling page under the bar, with a glass card of controls for its layout (adaptive, stacked, inline, compact inline, vertical), hugging or filling, 3 to 5 tabs, labels, clear or frosted glass, LTR or RTL with Arabic labels, the theme, minimize on scroll, the tick and a tinted lens.

```bash
flutter run
```

`lib/adaptive_tab_bar_layout.dart` is the recipe to copy into your app: it picks the bar's axis, size and screen edge the way iOS 27 does on iPhone, iPad and the iPhone Duo.

`integration_test/shader_test.dart` checks on a device or simulator that the refraction shader loads from the package (Impeller only). `integration_test/tab_bar_perf_test.dart` measures frame times while a page scrolls under the bar, a finger scrubs it and the lens slides; run it in profile mode on a device:

```bash
flutter drive --profile --driver=test_driver/perf_driver.dart --target=integration_test/tab_bar_perf_test.dart
```
