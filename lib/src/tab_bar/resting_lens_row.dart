import 'package:flutter/widgets.dart';

import '../glass_lens.dart';
import '../liquid_tab_bar_lens.dart';
import 'focus_ring.dart';

/// The row of tabs with the resting lens behind them, at [lens].
///
/// At rest the lens sits behind the tabs. With the shader ([refracts]) it
/// fades out as the clear lifted lens rises over them, and back in as it
/// drops, so the two never swap in one frame. Without the shader the lifted
/// lens covers the tabs, so their part under it is cut out: they show only
/// magnified, inside it.
class RestingLensRow extends StatelessWidget {
  /// The [tabs] with the resting lens at [lens], [lift] off the bar.
  const RestingLensRow({
    super.key,
    required this.lens,
    required this.lift,
    required this.refracts,
    required this.optics,
    required this.focusRing,
    required this.tabs,
  });

  /// Where the lens is, in the row.
  final Rect lens;

  /// 0 at rest, 1 lifted under a finger.
  final double lift;

  /// Whether the lifted lens refracts the tabs beneath it.
  final bool refracts;

  /// The lens's tint and shadows.
  final LiquidTabBarLens optics;

  /// The colour of the ring round the lens while the bar has keyboard
  /// focus; none draws no ring.
  final Color? focusRing;

  /// The bar's tabs.
  final Widget tabs;

  @override
  Widget build(BuildContext context) {
    final lifted = lift > 0;
    return Stack(
      children: [
        if (!lifted || refracts)
          Positioned.fromRect(
            rect: lens,
            child: Opacity(
              opacity: 1 - lift.clamp(0.0, 1.0),
              child: GlassLens(
                key: const Key('liquid_tab_bar_lens'),
                tint: optics.tint,
                shadows: optics.shadows,
                liftedShadows: optics.liftedShadows,
              ),
            ),
          ),
        ClipPath(
          clipper: lifted && !refracts ? _OutsideLens(lens) : null,
          child: tabs,
        ),
        if (focusRing case final color?)
          Positioned.fromRect(
            rect: lens.inflate(3),
            child: FocusRing(color: color),
          ),
      ],
    );
  }
}

/// Clips to everything except [lens].
class _OutsideLens extends CustomClipper<Path> {
  _OutsideLens(this.lens);

  final Rect lens;

  @override
  Path getClip(Size size) => Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(Offset.zero & size)
    ..addRRect(
      RRect.fromRectAndRadius(lens, Radius.circular(lens.shortestSide / 2)),
    );

  @override
  bool shouldReclip(_OutsideLens old) => old.lens != lens;
}
