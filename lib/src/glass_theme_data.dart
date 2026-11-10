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
    required this.regular,
    required this.frosted,
    required this.rim,
    required this.edge,
    required this.solid,
    required this.lensTint,
    required this.lensShadows,
    required this.lensLiftedShadows,
  });

  /// Neutral glass for light pages, with the looks of iOS 27.
  factory GlassThemeData.light() => const GlassThemeData(
    clear: GlassLook(
      frost: 1.5,
      fallbackFrost: 6,
      tint: Color(0x20FFFFFF),
      band: 20,
      bend: 44,
      dispersion: 0,
      specular: 0.5,
      sheen: 0,
      saturation: 1.2,
    ),
    regular: GlassLook(
      frost: 0,
      fallbackFrost: 8,
      tint: Color(0x87FFFFFF),
      band: 20,
      bend: 44,
      dispersion: 0,
      specular: 0.24,
      sheen: 0,
      saturation: 1.9,
      diffusion: 0.67,
    ),
    frosted: GlassLook(
      frost: 0,
      fallbackFrost: 30,
      tint: Color(0xB5FFFFFF),
      band: 16,
      bend: 6,
      dispersion: 0,
      specular: 0.24,
      sheen: 0,
      saturation: 1.9,
      diffusion: 0.92,
    ),
    rim: Color(0x54FFFFFF),
    edge: Color(0x4D000000),
    solid: Color(0xFFFFFFFF),
    lensTint: Color(0x1F000000),
    lensShadows: [],
    lensLiftedShadows: _lensLiftedShadows,
  );

  /// Neutral glass for dark pages, with the looks of iOS 27.
  factory GlassThemeData.dark() => const GlassThemeData(
    clear: GlassLook(
      frost: 1.5,
      fallbackFrost: 6,
      tint: Color(0x20FFFFFF),
      band: 20,
      bend: 44,
      dispersion: 0,
      specular: 0.5,
      sheen: 0,
      saturation: 1.2,
    ),
    regular: GlassLook(
      frost: 0,
      fallbackFrost: 8,
      tint: Color(0x20FFFFFF),
      band: 20,
      bend: 44,
      dispersion: 0,
      specular: 0.18,
      sheen: 0,
      saturation: 1.35,
      diffusion: 0.63,
      dim: 0.31,
    ),
    frosted: GlassLook(
      frost: 0,
      fallbackFrost: 30,
      tint: Color(0x80404040),
      band: 16,
      bend: 6,
      dispersion: 0,
      specular: 0.18,
      sheen: 0,
      saturation: 1.35,
      diffusion: 0.95,
      dim: 0.4,
    ),
    rim: Color(0x40FFFFFF),
    edge: Color(0x73000000),
    solid: Color(0xFF1C1C1E),
    lensTint: Color(0x40000000),
    lensShadows: [],
    lensLiftedShadows: _lensLiftedShadows,
  );

  static const _lensLiftedShadows = [
    BoxShadow(color: Color(0x29000000), blurRadius: 16, offset: Offset(0, 6)),
  ];

  /// See-through glass that refracts at the rim.
  final GlassLook clear;

  /// The standard glass of iOS 27: partly scattered and tinted.
  final GlassLook regular;

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
    GlassStyle.regular => regular,
    GlassStyle.frosted => frosted,
  };

  @override
  bool operator ==(Object other) =>
      other is GlassThemeData &&
      other.clear == clear &&
      other.regular == regular &&
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
    regular,
    frosted,
    rim,
    edge,
    solid,
    lensTint,
    Object.hashAll(lensShadows),
    Object.hashAll(lensLiftedShadows),
  );
}
