import 'package:flutter/widgets.dart';

/// The current tab inside the pill a minimized tab bar shrinks into,
/// fading in with [opacity] where the pill sits, at the start edge, so it
/// never drifts across the tabs while the bar grows.
class MinimizedPill extends StatelessWidget {
  /// [child] in a pill of [size], inside the glass's inset.
  const MinimizedPill({
    super.key,
    required this.opacity,
    required this.minimized,
    required this.size,
    required this.onTap,
    required this.child,
  });

  /// How far the current tab has faded in: 1 once the bar is a pill.
  final Animation<double> opacity;

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
          child: FadeTransition(opacity: opacity, child: child),
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
