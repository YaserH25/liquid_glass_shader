import 'package:flutter/rendering.dart';

/// Strokes the rim of rounded glass: [rim] at the top fading toward the
/// bottom, and an optional outer [edge] hairline all round, both faded by
/// [opacity].
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

  /// The rim's colour at the top, or none; it fades toward the bottom.
  final Color? rim;

  /// The outer hairline, or none.
  final Color? edge;

  /// How much of the rim and hairline shows, 0 to 1.
  final double opacity;

  Color _faded(Color color, double alpha) =>
      color.withValues(alpha: alpha * opacity);

  @override
  void paint(Canvas canvas, Size size) {
    // The hairlines sit half a pixel inside the glass; under one pixel there
    // is no room for them, and scaleRadii would fail.
    if (size.width < 1 || size.height < 1 || opacity <= 0) return;
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect.deflate(0.5)).scaleRadii();
    final edge = this.edge;
    if (edge != null) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = _faded(edge, edge.a),
      );
    }
    final rim = this.rim;
    if (rim == null) return;
    canvas.drawRRect(
      rrect.deflate(edge == null ? 0 : 0.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_faded(rim, rim.a), _faded(rim, 0.15), _faded(rim, 0.4)],
          stops: const [0, 0.6, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(GlassRimPainter old) =>
      old.borderRadius != borderRadius ||
      old.rim != rim ||
      old.edge != edge ||
      old.opacity != opacity;
}
