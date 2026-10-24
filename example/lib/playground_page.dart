import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:liquid_glass_shader/liquid_glass_shader.dart';

import 'adaptive_tab_bar_layout.dart';
import 'colorful_backdrop.dart';
import 'demo_tab.dart';
import 'demo_tab_look.dart';
import 'playground_controls.dart';
import 'playground_layout.dart';
import 'playground_settings.dart';

/// A colourful page under a liquid tab bar, with controls for every way the
/// bar can be set up. The bar floats over the page at the edge its layout
/// says, and shrinks into its pill while the page scrolls down.
class PlaygroundPage extends StatefulWidget {
  /// The page for [settings], reporting changes to [onChanged].
  const PlaygroundPage({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  /// How the bar is set up.
  final PlaygroundSettings settings;

  /// Called with the settings after a change in the controls.
  final ValueChanged<PlaygroundSettings> onChanged;

  @override
  State<PlaygroundPage> createState() => _PlaygroundPageState();
}

class _PlaygroundPageState extends State<PlaygroundPage> {
  int _tab = 0;
  bool _minimized = false;

  static const _icons = [
    Icons.home_rounded,
    Icons.search_rounded,
    Icons.photo_library_rounded,
    Icons.person_rounded,
    Icons.settings_rounded,
  ];
  static const _labels = ['Home', 'Search', 'Library', 'Profile', 'Settings'];
  static const _arabicLabels = [
    'الرئيسية',
    'البحث',
    'المكتبة',
    'حسابي',
    'الإعدادات',
  ];

  PlaygroundSettings get _settings => widget.settings;

  AdaptiveTabBarLayout _layout(BuildContext context) =>
      switch (_settings.layout) {
        PlaygroundLayout.adaptive => AdaptiveTabBarLayout.of(context),
        PlaygroundLayout.stacked => const AdaptiveTabBarLayout(
          metrics: LiquidTabBarMetrics.stacked,
          axis: Axis.horizontal,
          edge: AxisDirection.down,
        ),
        PlaygroundLayout.inline => const AdaptiveTabBarLayout(
          metrics: LiquidTabBarMetrics.inline,
          axis: Axis.horizontal,
          edge: AxisDirection.up,
        ),
        PlaygroundLayout.compactInline => const AdaptiveTabBarLayout(
          metrics: LiquidTabBarMetrics.compactInline,
          axis: Axis.horizontal,
          edge: AxisDirection.down,
        ),
        // A column for bars stays on the right in either direction, as on
        // the iPhone Duo.
        PlaygroundLayout.vertical => const AdaptiveTabBarLayout(
          metrics: LiquidTabBarMetrics.vertical,
          axis: Axis.vertical,
          edge: AxisDirection.right,
        ),
      };

  /// Minimizes the bar while the page scrolls down, and brings it back as
  /// it scrolls up.
  bool _onScroll(UserScrollNotification notification, bool minimizes) {
    if (!minimizes) return false;
    final down = switch (notification.direction) {
      ScrollDirection.reverse => true,
      ScrollDirection.forward => false,
      ScrollDirection.idle => null,
    };
    if (down != null && down != _minimized) {
      setState(() => _minimized = down);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final layout = _layout(context);
    final metrics = _settings.fill
        ? layout.metrics.copyWith(tabExtent: double.infinity)
        : layout.metrics;
    final minimizes = layout.minimizes && _settings.minimizeOnScroll;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final labels = rtl ? _arabicLabels : _labels;
    final look = !_settings.labels || layout.axis == Axis.vertical
        ? DemoTabLook.icon
        : layout.edge == AxisDirection.down &&
              metrics.thickness >= LiquidTabBarMetrics.stacked.thickness
        ? DemoTabLook.stacked
        : DemoTabLook.inline;
    final colors = Theme.of(context).colorScheme;

    final bar = LiquidTabBar(
      tabCount: _settings.tabCount,
      selectedIndex: math.min(_tab, _settings.tabCount - 1),
      onSelected: (index) => setState(() => _tab = index),
      axis: layout.axis,
      metrics: metrics,
      // Apple's side column sits at the bottom of the screen's edge.
      alignment: layout.axis == Axis.vertical
          ? Alignment.bottomCenter
          : Alignment.center,
      lens: LiquidTabBarLens(
        tint: _settings.tintedLens
            ? colors.primary.withValues(alpha: 0.3)
            : null,
      ),
      onTick: _settings.tick ? LiquidTabBar.selectionClick : null,
      minimized: minimizes && _minimized,
      onExpand: () => setState(() => _minimized = false),
      shadows: const [
        BoxShadow(
          color: Color(0x29000000),
          blurRadius: 24,
          offset: Offset(0, 8),
        ),
      ],
      tabBuilder: (context, index, active) => DemoTab(
        icon: _icons[index],
        label: labels[index],
        active: active,
        look: look,
      ),
    );

    final screen = MediaQuery.viewPaddingOf(context);
    // The bar sits 21 in from the screen's edges, as on iPhone, and the
    // page keeps clear of it.
    const margin = 21.0;
    final room = metrics.thickness + margin + 8;
    final column = math.max(screen.right, room);
    final page = EdgeInsets.fromLTRB(
      16 + screen.left,
      16 + screen.top + (layout.edge == AxisDirection.up ? room : 0),
      16 + (layout.edge == AxisDirection.right ? column : screen.right),
      16 + screen.bottom + (layout.edge == AxisDirection.down ? room : 0),
    );

    return Stack(
      children: [
        NotificationListener<UserScrollNotification>(
          onNotification: (notification) => _onScroll(notification, minimizes),
          child: ColorfulBackdrop(
            padding: page,
            header: PlaygroundControls(
              settings: _settings,
              onChanged: widget.onChanged,
            ),
          ),
        ),
        switch (layout.edge) {
          AxisDirection.down => Positioned(
            left: screen.left + margin,
            right: screen.right + margin,
            bottom: screen.bottom > 0 ? margin : 12,
            child: bar,
          ),
          AxisDirection.up => Positioned(
            left: screen.left + margin,
            right: screen.right + margin,
            top: screen.top + 8,
            child: bar,
          ),
          AxisDirection.right || AxisDirection.left => Positioned(
            top: screen.top + 12,
            bottom: screen.bottom > 0 ? 24 : 12,
            right: layout.edge == AxisDirection.right
                ? math.max((screen.right - metrics.thickness) / 2, 12)
                : null,
            left: layout.edge == AxisDirection.left
                ? math.max((screen.left - metrics.thickness) / 2, 12)
                : null,
            width: metrics.thickness,
            child: bar,
          ),
        },
      ],
    );
  }
}
