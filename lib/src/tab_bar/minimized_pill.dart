import 'package:flutter/widgets.dart';

/// The current tab inside the pill a minimized tab bar shrinks into,
/// fading in with [minimize] where the pill sits, at the start edge, so it
/// never drifts across the tabs while the bar grows.
class MinimizedPill extends StatelessWidget {
  /// [child] in a pill of [size], inside the glass's inset.
  const MinimizedPill({
    super.key,
    required this.minimize,
    required this.minimized,
    required this.size,
    required this.onTap,
    required this.child,
  });

  /// 0 as the full bar, 1 shrunk into the pill.
  final double minimize;

  /// Whether the bar is minimized, rather than shrinking or growing; only
  /// then does the pill take taps.
  final bool minimized;

  /// The pill's content box, inside the glass's inset.
  final double size;

  /// Called on a tap on the minimized pill, or by a screen reader.
  final VoidCallback? onTap;

  /// The current tab.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final content = Align(
      alignment: AlignmentDirectional.centerStart,
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: Opacity(opacity: minimize, child: child),
        ),
      ),
    );
    if (!minimized) return content;
    return Semantics(
      button: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: content,
      ),
    );
  }
}
