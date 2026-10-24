import 'package:flutter/widgets.dart';

import 'glass_rim_painter.dart';
import 'glass_scope.dart';

/// The selected tab's lens: a brighter capsule of glass with its own rim.
///
/// [lift] (0 at rest, 1 under a finger) clears the tint, so the lens reads
/// as clear glass, and deepens its shadow. Colours and shadows not given
/// come from [GlassScope.themeOf].
class GlassLens extends StatelessWidget {
  /// A lens filling its box.
  const GlassLens({
    super.key,
    this.lift = 0,
    this.tint,
    this.shadows,
    this.liftedShadows,
  });

  /// 0 at rest, 1 lifted under a finger.
  final double lift;

  /// The tint at rest; none takes the theme's `GlassThemeData.lensTint`.
  final Color? tint;

  /// The shadow at rest; none takes the theme's
  /// `GlassThemeData.lensShadows`.
  final List<BoxShadow>? shadows;

  /// The shadow lifted; none takes the theme's
  /// `GlassThemeData.lensLiftedShadows`.
  final List<BoxShadow>? liftedShadows;

  @override
  Widget build(BuildContext context) {
    final theme = GlassScope.themeOf(context);
    final t = lift.clamp(0.0, 1.0);
    final radius = BorderRadius.circular(999);
    return Stack(
      fit: StackFit.expand,
      children: [
        // The shadow only falls outside the lens; through the clear glass
        // it would read as a grey stain.
        ClipPath(
          clipper: const _OutsideCapsule(),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: BoxShadow.lerpList(
                shadows ?? theme.lensShadows,
                liftedShadows ?? theme.lensLiftedShadows,
                t,
              ),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Color.lerp(
              tint ?? theme.lensTint,
              theme.rim.withValues(alpha: 0.12),
              t,
            ),
            borderRadius: radius,
          ),
          child: CustomPaint(
            painter: GlassRimPainter(borderRadius: radius, rim: theme.rim),
          ),
        ),
      ],
    );
  }
}

/// Clips to everything around a capsule that fills the box, reaching far
/// enough out to keep the whole shadow.
class _OutsideCapsule extends CustomClipper<Path> {
  const _OutsideCapsule();

  /// Beyond the reach of any lens shadow (blur plus offset).
  static const double _shadowReach = 48;

  @override
  Path getClip(Size size) {
    final box = Offset.zero & size;
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(box.inflate(_shadowReach))
      ..addRRect(
        RRect.fromRectAndRadius(box, Radius.circular(size.shortestSide / 2)),
      );
  }

  @override
  bool shouldReclip(_OutsideCapsule old) => false;
}
