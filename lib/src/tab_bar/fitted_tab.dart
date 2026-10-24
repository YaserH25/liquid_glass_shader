import 'package:flutter/widgets.dart';

/// A tab in its slot: as wide as the slot and as tall as it needs, centred,
/// and scaled down when it would not fit (large text in a small bar), so it
/// never clips or overflows.
class FittedTab extends StatelessWidget {
  /// [child] fitted into the slot this is given.
  const FittedTab({super.key, required this.child});

  /// The tab.
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, slot) => FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(width: slot.maxWidth, child: child),
    ),
  );
}
