import 'package:flutter/foundation.dart';

/// How a `LiquidTabBar`'s lens looks: its size and optics once lifted under
/// a finger. The defaults match the iOS 26 tab bar.
@immutable
class LiquidTabBarLens {
  /// A lens; every value has a default.
  const LiquidTabBarLens({
    this.liftedExtent = 1.18,
    this.liftedThickness = 1.3,
    this.magnification = 1.17,
    this.band = 22,
    this.bend = 18,
    this.dispersion = 0.5,
    this.specular = 0.55,
  });

  /// The default lens.
  static const LiquidTabBarLens standard = LiquidTabBarLens();

  /// The lifted lens's length along the bar against the resting lens's.
  final double liftedExtent;

  /// The lifted lens's thickness across the bar against the resting lens's,
  /// so it stands out over the bar.
  final double liftedThickness;

  /// How much the lifted lens magnifies the tabs under it.
  final double magnification;

  /// How far in from its rim the lifted lens curves, in logical pixels.
  final double band;

  /// How far the lifted lens bends what is under it at the rim, in logical
  /// pixels.
  final double bend;

  /// Colour split at the lifted lens's rim, as a fraction of [bend].
  final double dispersion;

  /// Light caught along the top of the lifted lens's rim (0 to 1).
  final double specular;

  /// A copy with the given values replaced.
  LiquidTabBarLens copyWith({
    double? liftedExtent,
    double? liftedThickness,
    double? magnification,
    double? band,
    double? bend,
    double? dispersion,
    double? specular,
  }) => LiquidTabBarLens(
    liftedExtent: liftedExtent ?? this.liftedExtent,
    liftedThickness: liftedThickness ?? this.liftedThickness,
    magnification: magnification ?? this.magnification,
    band: band ?? this.band,
    bend: bend ?? this.bend,
    dispersion: dispersion ?? this.dispersion,
    specular: specular ?? this.specular,
  );

  @override
  bool operator ==(Object other) =>
      other is LiquidTabBarLens &&
      other.liftedExtent == liftedExtent &&
      other.liftedThickness == liftedThickness &&
      other.magnification == magnification &&
      other.band == band &&
      other.bend == bend &&
      other.dispersion == dispersion &&
      other.specular == specular;

  @override
  int get hashCode => Object.hash(
    liftedExtent,
    liftedThickness,
    magnification,
    band,
    bend,
    dispersion,
    specular,
  );
}
