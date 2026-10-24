import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// One look of liquid glass: how much it frosts and tints what is behind
/// it, and how its rim refracts and catches the light.
@immutable
class GlassLook {
  /// A look with the given optics.
  const GlassLook({
    required this.frost,
    required this.fallbackFrost,
    required this.tint,
    required this.band,
    required this.bend,
    required this.dispersion,
    required this.specular,
    required this.sheen,
    this.saturation = 1.8,
  });

  /// Blur sigma behind refracting glass.
  final double frost;

  /// Blur sigma behind the blur-only fallback.
  final double fallbackFrost;

  /// Laid over the glass.
  final Color tint;

  /// How far in from the rim the glass curves, in logical pixels.
  final double band;

  /// How far the glass bends the content at the rim, in logical pixels.
  final double bend;

  /// Colour split at the rim, as a fraction of [bend].
  final double dispersion;

  /// The light caught along the top of the rim (0 to 1).
  final double specular;

  /// How bright the sheen over the top half is (0 to 1).
  final double sheen;

  /// Colour saturation of what shows through (1 = unchanged), so it looks
  /// vivid rather than washed out.
  final double saturation;

  @override
  bool operator ==(Object other) =>
      other is GlassLook &&
      other.frost == frost &&
      other.fallbackFrost == fallbackFrost &&
      other.tint == tint &&
      other.band == band &&
      other.bend == bend &&
      other.dispersion == dispersion &&
      other.specular == specular &&
      other.sheen == sheen &&
      other.saturation == saturation;

  @override
  int get hashCode => Object.hash(
    frost,
    fallbackFrost,
    tint,
    band,
    bend,
    dispersion,
    specular,
    sheen,
    saturation,
  );
}
