/// For each piece of glass attached to the render tree, whether it drew a
/// backdrop in the frame just drawn.
///
/// Attached is not enough: a page covered by another one, or glass under an
/// `Offstage`, keeps its render objects but paints nothing, and costs
/// nothing. The performance guard judges a frame only when some glass drew
/// a backdrop in it, because only then can glass have made it late.
final Set<bool Function()> attachedGlass = {};

/// Whether any glass drew a backdrop in the frame just drawn.
bool get glassOnScreen => attachedGlass.any((drewBackdrop) => drewBackdrop());
