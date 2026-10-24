import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The sizes of a `LiquidTabBar`.
///
/// The presets carry the sizes of the system tab bar on iOS 27, measured on
/// the simulators (Apple publishes none): [stacked] for an iPhone held
/// upright, [inline] for iPad, [compactInline] for an iPhone held sideways.
/// Each only sets sizes; draw the tabs to match (icon above label, or beside
/// it) in the bar's `tabBuilder`.
@immutable
class LiquidTabBarMetrics {
  /// Sizes; every value has a default, those of [stacked].
  const LiquidTabBarMetrics({
    this.thickness = 62,
    this.tabExtent = 90,
    this.inset = 4,
    this.lensGap = EdgeInsets.zero,
    this.minimizedSize,
    this.borderRadius,
  }) : assert(thickness > 2 * inset),
       assert(tabExtent > 0);

  /// Icon above label, as on an iPhone held upright: 62 thick.
  static const LiquidTabBarMetrics stacked = LiquidTabBarMetrics();

  /// Icon beside label, or the label alone, as on iPad: 46 thick.
  static const LiquidTabBarMetrics inline = LiquidTabBarMetrics(
    thickness: 46,
    tabExtent: 74,
  );

  /// The smallest, as on an iPhone held sideways: 44 thick. Below 44, a
  /// tab gets hard to hit.
  static const LiquidTabBarMetrics compactInline = LiquidTabBarMetrics(
    thickness: 44,
    tabExtent: 78,
  );

  /// The whole bar across, glass included: the height of a bar along the
  /// bottom of a screen.
  final double thickness;

  /// The longest a tab's slot gets along the bar. The bar hugs its tabs at
  /// this length, but is never longer than its space, so it fills that
  /// instead when there is not room. `double.infinity` always fills.
  final double tabExtent;

  /// The space between the glass's edge and the tabs, on every side.
  final double inset;

  /// The space between the resting lens and the edges of its tab's slot.
  final EdgeInsets lensGap;

  /// The pill a minimized bar shrinks into, across and along, glass
  /// included; none makes it as thick as the bar. Keep it at least 44 so it
  /// stays easy to tap.
  final double? minimizedSize;

  /// The glass's corners; none makes a capsule.
  final BorderRadiusGeometry? borderRadius;

  /// A copy with the given values replaced.
  LiquidTabBarMetrics copyWith({
    double? thickness,
    double? tabExtent,
    double? inset,
    EdgeInsets? lensGap,
    double? minimizedSize,
    BorderRadiusGeometry? borderRadius,
  }) => LiquidTabBarMetrics(
    thickness: thickness ?? this.thickness,
    tabExtent: tabExtent ?? this.tabExtent,
    inset: inset ?? this.inset,
    lensGap: lensGap ?? this.lensGap,
    minimizedSize: minimizedSize ?? this.minimizedSize,
    borderRadius: borderRadius ?? this.borderRadius,
  );

  @override
  bool operator ==(Object other) =>
      other is LiquidTabBarMetrics &&
      other.thickness == thickness &&
      other.tabExtent == tabExtent &&
      other.inset == inset &&
      other.lensGap == lensGap &&
      other.minimizedSize == minimizedSize &&
      other.borderRadius == borderRadius;

  @override
  int get hashCode => Object.hash(
    thickness,
    tabExtent,
    inset,
    lensGap,
    minimizedSize,
    borderRadius,
  );
}
