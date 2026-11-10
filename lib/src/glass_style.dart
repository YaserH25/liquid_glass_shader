/// How liquid glass looks. An app can let its users pick it; a surface can
/// insist on one where readability needs it.
enum GlassStyle {
  /// Clear glass that refracts what is behind it, lightly frosted: for
  /// glass over photos and video.
  clear,

  /// The standard glass of iOS 27: what is behind stays in view, but partly
  /// scattered and tinted, so a busy page keeps its place without fighting
  /// the labels on the glass.
  regular,

  /// Milky glass: heavily frosted and tinted, so what is behind it reads
  /// only as colour.
  frosted,
}
