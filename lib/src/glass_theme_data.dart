import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'glass_look.dart';
import 'glass_style.dart';

/// The colours and looks every glass surface below a `GlassScope` uses.
@immutable
class GlassThemeData {
  /// A theme with the given looks and colours.
  const GlassThemeData({
    required this.clear,
    required this.frosted,
    required this.rim,
    required this.edge,
    required this.solid,
    required this.lensTint,
    required this.lensShadows,
    required this.lensLiftedShadows,
  });

  /// Neutral glass for light pages.
  factory GlassThemeData.light() => const GlassThemeData(
    clear: GlassLook(
      frost: 1.5,
      fallbackFrost: 6,
      tint: Color(0x14FFFFFF),
      band: 16,
      bend: 14,
      dispersion: 0.15,
      specular: 0.3,
      sheen: 0.12,
    ),
    frosted: GlassLook(
      frost: 30,
      fallbackFrost: 30,
      tint: Color(0x9EFFFFFF),
      band: 16,
      bend: 6,
      dispersion: 0.05,
      specular: 0.3,
      sheen: 0.28,
    ),
    rim: Color(0xE6FFFFFF),
    edge: Color(0x1F000000),
    solid: Color(0xFFFFFFFF),
    lensTint: Color(0x99FFFFFF),
    lensShadows: _lensShadows,
    lensLiftedShadows: _lensLiftedShadows,
  );

  /// Neutral glass for dark pages.
  factory GlassThemeData.dark() => const GlassThemeData(
    clear: GlassLook(
      frost: 1.5,
      fallbackFrost: 6,
      tint: Color(0x401C1C1E),
      band: 16,
      bend: 14,
      dispersion: 0.15,
      specular: 0.3,
      sheen: 0.12,
    ),
    frosted: GlassLook(
      frost: 30,
      fallbackFrost: 30,
      tint: Color(0xB31C1C1E),
      band: 16,
      bend: 6,
      dispersion: 0.05,
      specular: 0.3,
      sheen: 0.28,
    ),
    rim: Color(0x4DFFFFFF),
    edge: Color(0x66000000),
    solid: Color(0xFF1C1C1E),
    lensTint: Color(0x29FFFFFF),
    lensShadows: _lensShadows,
    lensLiftedShadows: _lensLiftedShadows,
  );

  static const _lensShadows = [
    BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
  ];
  static const _lensLiftedShadows = [
    BoxShadow(color: Color(0x29000000), blurRadius: 16, offset: Offset(0, 6)),
  ];

  /// See-through glass that refracts at the rim.
  final GlassLook clear;

  /// Milky glass; what is behind reads only as soft colour.
  final GlassLook frosted;

  /// The light-catching rim and the sheen over the top half.
  final Color rim;

  /// The outer hairline that separates glass from a light backdrop.
  final Color edge;

  /// The opaque fill used when glass draws no backdrop (high contrast, or a
  /// device that cannot keep up).
  final Color solid;

  /// The resting tab-bar lens.
  final Color lensTint;

  /// Shadow of the resting lens.
  final List<BoxShadow> lensShadows;

  /// Shadow of the lens lifted under a finger.
  final List<BoxShadow> lensLiftedShadows;

  /// The look for [style].
  GlassLook look(GlassStyle style) => switch (style) {
    GlassStyle.clear => clear,
    GlassStyle.frosted => frosted,
  };

  @override
  bool operator ==(Object other) =>
      other is GlassThemeData &&
      other.clear == clear &&
      other.frosted == frosted &&
      other.rim == rim &&
      other.edge == edge &&
      other.solid == solid &&
      other.lensTint == lensTint &&
      listEquals(other.lensShadows, lensShadows) &&
      listEquals(other.lensLiftedShadows, lensLiftedShadows);

  @override
  int get hashCode => Object.hash(
    clear,
    frosted,
    rim,
    edge,
    solid,
    lensTint,
    Object.hashAll(lensShadows),
    Object.hashAll(lensLiftedShadows),
  );
}
