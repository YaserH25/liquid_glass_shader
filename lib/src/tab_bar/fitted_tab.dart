import 'package:flutter/widgets.dart';

/// A tab in its slot: laid out at its own size, centred, and scaled down
/// when it would not fit (a long label, or large text in a small bar), so
/// it is never cut short, clipped or overflowing. A tab therefore needs a
/// size of its own: no `Expanded` or infinite sizes inside it.
class FittedTab extends StatelessWidget {
  /// [child] fitted into the slot this is given.
  const FittedTab({super.key, required this.child});

  /// The tab.
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      FittedBox(fit: BoxFit.scaleDown, child: child);
}
