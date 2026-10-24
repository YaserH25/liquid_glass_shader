import 'package:flutter/widgets.dart';
import 'package:liquid_glass_shader/liquid_glass_shader.dart';

/// Where a tab bar goes on this screen, and how big it is, the way iOS 27
/// lays out its own. Placing the bar is the app's job, not the package's:
/// copy this into your app and change what you like.
///
/// * A screen that keeps a column at one side for its bars, like the iPhone
///   Duo's cover screen: [LiquidTabBarMetrics.vertical], standing in that
///   column.
/// * A short screen, like an iPhone held sideways:
///   [LiquidTabBarMetrics.compactInline] along the bottom.
/// * A tablet, or an unfolded phone, at least 600 both ways:
///   [LiquidTabBarMetrics.inline] along the top.
/// * Anything else, like an iPhone held upright: [LiquidTabBarMetrics.stacked]
///   along the bottom.
@immutable
class AdaptiveTabBarLayout {
  /// A bar of [metrics] along [axis], at the [edge] of the screen.
  const AdaptiveTabBarLayout({
    required this.metrics,
    required this.axis,
    required this.edge,
  });

  /// The layout for the screen [context] is on.
  factory AdaptiveTabBarLayout.of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.viewPaddingOf(context);
    // A phone held sideways keeps the same room on both sides for its
    // camera; a column for bars takes one side only.
    final column = padding.right - padding.left;
    if (column.abs() >= 44) {
      return AdaptiveTabBarLayout(
        metrics: LiquidTabBarMetrics.vertical,
        axis: Axis.vertical,
        edge: column > 0 ? AxisDirection.right : AxisDirection.left,
      );
    }
    if (size.height < 500) {
      return const AdaptiveTabBarLayout(
        metrics: LiquidTabBarMetrics.compactInline,
        axis: Axis.horizontal,
        edge: AxisDirection.down,
      );
    }
    if (size.shortestSide >= 600) {
      return const AdaptiveTabBarLayout(
        metrics: LiquidTabBarMetrics.inline,
        axis: Axis.horizontal,
        edge: AxisDirection.up,
      );
    }
    return const AdaptiveTabBarLayout(
      metrics: LiquidTabBarMetrics.stacked,
      axis: Axis.horizontal,
      edge: AxisDirection.down,
    );
  }

  /// The bar's sizes.
  final LiquidTabBarMetrics metrics;

  /// The direction its tabs follow each other in.
  final Axis axis;

  /// The edge of the screen it sits along.
  final AxisDirection edge;

  /// Whether it should shrink into its pill while a page scrolls down: only
  /// a bar along the bottom, as iOS does on iPhone.
  bool get minimizes => edge == AxisDirection.down;
}
