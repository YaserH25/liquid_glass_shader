/// How much work glass does, from most to least.
enum GlassQuality {
  /// The refraction shader (Impeller).
  refraction,

  /// A frosted blur only.
  blur,

  /// No backdrop at all: an opaque surface with the glass rim.
  solid,
}
