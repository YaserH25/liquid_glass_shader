import 'package:flutter/material.dart';
import 'package:liquid_glass_shader/liquid_glass_shader.dart';

import 'playground_layout.dart';

/// Everything the playground's controls change.
@immutable
class PlaygroundSettings {
  /// Settings; the defaults show the bar as iOS does.
  const PlaygroundSettings({
    this.layout = PlaygroundLayout.adaptive,
    this.fill = false,
    this.tabCount = 4,
    this.labels = true,
    this.glass = GlassStyle.clear,
    this.rtl = false,
    this.themeMode = ThemeMode.system,
    this.minimizeOnScroll = true,
    this.tick = true,
    this.tintedLens = false,
  });

  /// The bar's layout.
  final PlaygroundLayout layout;

  /// Whether the bar fills its length instead of hugging its tabs.
  final bool fill;

  /// How many tabs, 3 to 5.
  final int tabCount;

  /// Whether the tabs show their labels.
  final bool labels;

  /// Clear or frosted glass.
  final GlassStyle glass;

  /// Whether the app runs right to left, with Arabic labels.
  final bool rtl;

  /// Light, dark, or as the system is.
  final ThemeMode themeMode;

  /// Whether the bar shrinks into its pill while the page scrolls down.
  final bool minimizeOnScroll;

  /// Whether the lens ticks as it crosses each tab.
  final bool tick;

  /// Whether the lens takes the app's colour.
  final bool tintedLens;

  /// A copy with the given values replaced.
  PlaygroundSettings copyWith({
    PlaygroundLayout? layout,
    bool? fill,
    int? tabCount,
    bool? labels,
    GlassStyle? glass,
    bool? rtl,
    ThemeMode? themeMode,
    bool? minimizeOnScroll,
    bool? tick,
    bool? tintedLens,
  }) => PlaygroundSettings(
    layout: layout ?? this.layout,
    fill: fill ?? this.fill,
    tabCount: tabCount ?? this.tabCount,
    labels: labels ?? this.labels,
    glass: glass ?? this.glass,
    rtl: rtl ?? this.rtl,
    themeMode: themeMode ?? this.themeMode,
    minimizeOnScroll: minimizeOnScroll ?? this.minimizeOnScroll,
    tick: tick ?? this.tick,
    tintedLens: tintedLens ?? this.tintedLens,
  );
}
