import 'dart:math' as math;

import 'package:flutter/rendering.dart';

/// Strokes the rim of rounded glass as iOS 27 lights it: [rim] where the
/// glass faces up or down, along the top and the bottom, and none at the
/// sides; and an optional outer [edge] hairline, darkest at the sides and
/// faint along the top and the bottom. Both are faded by [opacity].
class GlassRimPainter extends CustomPainter {
  /// Strokes the rim of glass shaped by [borderRadius].
  GlassRimPainter({
    required this.borderRadius,
    this.rim,
    this.edge,
    this.opacity = 1,
  });

  /// The glass's corners.
  final BorderRadius borderRadius;

  /// The rim's colour along the top and the bottom, or none.
  final Color? rim;

  /// The outer hairline's colour at the sides, or none.
  final Color? edge;

  /// How much of the rim and hairline shows, 0 to 1.
  final double opacity;

  /// The share of the hairline's colour left along the top and the bottom.
  static const double _edgeFacingUp = 0.3;

  static const double _edgeWidth = 2 / 3;

  Color _faded(Color color, double alpha) =>
      color.withValues(alpha: alpha * opacity);

  @override
  void paint(Canvas canvas, Size size) {
    // The hairlines sit just inside the glass; under two pixels there is no
    // room for them, and scaleRadii would fail.
    if (size.width < 2 || size.height < 2 || opacity <= 0) return;
    final rect = Offset.zero & size;
    final edge = this.edge;
    // The hairline is two thirds of a pixel wide, as on iOS, with the rim
    // right inside it.
    final outline = edge == null ? 0.0 : _edgeWidth;
    final rrect = borderRadius.toRRect(rect).scaleRadii();
    // The rim turns from facing up to facing sideways down each corner, so
    // the light fades over the corner's height, top and bottom.
    final turn =
        ([
                  rrect.tlRadiusY,
                  rrect.trRadiusY,
                  rrect.blRadiusY,
                  rrect.brRadiusY,
                ].reduce(math.max) /
                size.height)
            .clamp(0.5 / size.height, 0.5);
    Shader facing(Color up, Color sideways) => LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [up, sideways, sideways, up],
      stops: [0, turn * 0.8, 1 - turn * 0.8, 1],
    ).createShader(rect);

    if (edge != null) {
      canvas.drawRRect(
        rrect.deflate(outline / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = outline
          ..shader = facing(
            _faded(edge, edge.a * _edgeFacingUp),
            _faded(edge, edge.a),
          ),
      );
    }
    final rim = this.rim;
    if (rim == null) return;
    canvas.drawRRect(
      rrect.deflate(outline + 0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = facing(_faded(rim, rim.a), _faded(rim, 0)),
    );
  }

  @override
  bool shouldRepaint(GlassRimPainter old) =>
      old.borderRadius != borderRadius ||
      old.rim != rim ||
      old.edge != edge ||
      old.opacity != opacity;
}
