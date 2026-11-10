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
    this.diffusion = 0,
    this.dim = 0,
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

  /// The share of what shows through that is scattered widely, 0 to 1; the
  /// rest stays as sharp as [frost] leaves it. A busy page loses its
  /// contrast behind the glass without turning to fog, as behind the
  /// standard glass of iOS 27. Refracting glass only: the fallback blurs by
  /// [fallbackFrost].
  final double diffusion;

  /// How much bright content behind refracting glass is dimmed, 0 to 1, so
  /// light labels stay readable on dark glass over a bright page.
  final double dim;

  /// The look between [a] and [b] at [t], 0 to 1.
  static GlassLook lerp(GlassLook a, GlassLook b, double t) {
    // Exact at both ends, so the look at 0 or 1 equals a or b.
    double mix(double from, double to) => from * (1 - t) + to * t;
    return GlassLook(
      frost: mix(a.frost, b.frost),
      fallbackFrost: mix(a.fallbackFrost, b.fallbackFrost),
      tint: Color.lerp(a.tint, b.tint, t)!,
      band: mix(a.band, b.band),
      bend: mix(a.bend, b.bend),
      dispersion: mix(a.dispersion, b.dispersion),
      specular: mix(a.specular, b.specular),
      sheen: mix(a.sheen, b.sheen),
      saturation: mix(a.saturation, b.saturation),
      diffusion: mix(a.diffusion, b.diffusion),
      dim: mix(a.dim, b.dim),
    );
  }

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
      other.saturation == saturation &&
      other.diffusion == diffusion &&
      other.dim == dim;

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
    diffusion,
    dim,
  );
}
