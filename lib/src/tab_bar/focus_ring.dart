import 'package:flutter/widgets.dart';

/// The ring a tab bar draws round its lens, or its pill, while it has
/// keyboard focus.
class FocusRing extends StatelessWidget {
  /// A [color] ring filling its box, as round as [borderRadius].
  const FocusRing({
    super.key = const Key('liquid_tab_bar_focus'),
    required this.color,
    this.borderRadius,
  });

  /// The ring's colour.
  final Color color;

  /// The ring's corners; none makes a capsule.
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final side = BorderSide(color: color, width: 2);
    final radius = borderRadius;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: radius == null
              ? StadiumBorder(side: side)
              : RoundedRectangleBorder(borderRadius: radius, side: side),
        ),
      ),
    );
  }
}
