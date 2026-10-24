import 'package:flutter/widgets.dart';

import '../glass_backdrop.dart';
import '../glass_lens.dart';
import '../liquid_tab_bar_style.dart';

/// The lens lifted under a finger, standing over the bar at [lens]: clear
/// glass, larger than a tab, magnifying the tabs under it.
///
/// With the shader ([refracts]) it refracts the bar's real tabs beneath it.
/// Without, it shows [tabs], a copy of the row, magnified over the cut-out
/// the resting row leaves under it.
class LiftedLens extends StatelessWidget {
  /// The lens at [lens] in a row of [row], [lift] off the bar.
  const LiftedLens({
    super.key,
    required this.lens,
    required this.row,
    required this.lift,
    required this.refracts,
    required this.style,
    required this.tabs,
  });

  /// Where the lens is, in the row.
  final Rect lens;

  /// The size of the row of tabs.
  final Size row;

  /// 0 at rest, 1 lifted under a finger.
  final double lift;

  /// Whether the lens refracts the tabs beneath it.
  final bool refracts;

  /// The lens's optics and magnification.
  final LiquidTabBarStyle style;

  /// A copy of the row, every tab drawn as current, for the lens to magnify.
  final Widget tabs;

  @override
  Widget build(BuildContext context) {
    final magnification = 1 + (style.magnification - 1) * lift;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fromRect(
          key: const Key('liquid_tab_bar_lifted_lens'),
          rect: lens,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (refracts)
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: GlassBackdrop(
                    band: style.lensBand,
                    bend: style.lensBend * lift,
                    dispersion: style.lensDispersion,
                    specular: style.lensSpecular * lift,
                    magnify: magnification,
                    child: const SizedBox.expand(),
                  ),
                ),
              if (refracts)
                // Clear glass whose rim and shadow fade with the lift; the
                // resting lens behind the tabs supplies the tint.
                Opacity(
                  opacity: lift.clamp(0.0, 1.0),
                  child: const GlassLens(lift: 1),
                )
              else ...[
                GlassLens(lift: lift),
                _magnified(magnification),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// The tabs under the lens, magnified about its centre and aligned with
  /// the bar's own row.
  Widget _magnified(double magnification) => ClipRRect(
    borderRadius: BorderRadius.circular(999),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -lens.left,
          top: -lens.top,
          width: row.width,
          height: row.height,
          child: Transform.scale(
            scale: magnification,
            alignment: Alignment.topLeft,
            origin: lens.center,
            child: tabs,
          ),
        ),
      ],
    ),
  );
}
