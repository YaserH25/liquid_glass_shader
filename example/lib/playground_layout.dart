/// Which tab bar layout the playground shows.
enum PlaygroundLayout {
  /// What `AdaptiveTabBarLayout.of` picks for this screen.
  adaptive('Adaptive'),

  /// Icon above label, along the bottom.
  stacked('Stacked'),

  /// Icon beside label, along the top.
  inline('Inline'),

  /// The smallest bar, along the bottom.
  compactInline('Compact'),

  /// A column at the side.
  vertical('Vertical');

  const PlaygroundLayout(this.label);

  /// Its name in the controls.
  final String label;
}
