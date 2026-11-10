import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_shader/liquid_glass_shader.dart';
import 'package:liquid_glass_shader/src/glass_rim_painter.dart';

const _size = Size(200, 60);
final _radius = BorderRadius.circular(30);

/// The strokes [painter] draws.
List<RecordedInvocation> _strokes(GlassRimPainter painter) {
  final canvas = TestRecordingCanvas();
  painter.paint(canvas, _size);
  return canvas.invocations
      .where((call) => call.invocation.memberName == #drawRRect)
      .toList();
}

/// How opaque [painter] leaves the outermost pixel of the glass at the
/// middle of its top, of its bottom and of its left side.
Future<({double top, double bottom, double side})> _alphas(
  WidgetTester tester,
  GlassRimPainter painter,
) async {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), _size);
  final picture = recorder.endRecording();
  late ByteData bytes;
  await tester.runAsync(() async {
    final image = await picture.toImage(
      _size.width.toInt(),
      _size.height.toInt(),
    );
    bytes = (await image.toByteData())!;
    image.dispose();
  });
  picture.dispose();
  double alpha(int x, int y) =>
      bytes.getUint8((y * _size.width.toInt() + x) * 4 + 3) / 255;
  return (
    top: alpha(100, 0),
    bottom: alpha(100, _size.height.toInt() - 1),
    side: alpha(0, 30),
  );
}

/// The rim painters on the glass surface.
Iterable<GlassRimPainter> _rims(WidgetTester tester) => tester
    .widgetList<CustomPaint>(
      find.descendant(
        of: find.byType(GlassSurface),
        matching: find.byType(CustomPaint),
      ),
    )
    .map((paint) => paint.foregroundPainter)
    .whereType<GlassRimPainter>();

GlassRimPainter _rimOf(WidgetTester tester) => _rims(tester).single;

Widget _surface({bool rim = true, double strength = 1}) => MaterialApp(
  home: Center(
    child: SizedBox.fromSize(
      size: _size,
      child: GlassSurface(
        rim: rim,
        strength: strength,
        child: const SizedBox.expand(),
      ),
    ),
  ),
);

void main() {
  test('strokes the edge and the rim', () {
    expect(
      _strokes(
        GlassRimPainter(
          borderRadius: _radius,
          rim: const Color(0xE6FFFFFF),
          edge: const Color(0x1F000000),
        ),
      ),
      hasLength(2),
    );
  });

  // The rim's lower stops once took a fixed alpha of the rim's colour, so
  // glass with no rim (a transparent black) still drew a dark line round
  // its lower half.
  test('with no rim, strokes only the edge', () {
    expect(
      _strokes(
        GlassRimPainter(borderRadius: _radius, edge: const Color(0x1F000000)),
      ),
      hasLength(1),
    );
  });

  // iOS 27 lights the rim where it faces up or down, and darkens the
  // hairline where it faces sideways.
  testWidgets('the rim is lit above and below, the edge dark at the sides', (
    tester,
  ) async {
    const rim = Color(0x54FFFFFF), edge = Color(0x4D000000);
    final lit = await _alphas(
      tester,
      GlassRimPainter(borderRadius: _radius, rim: rim),
    );
    expect(lit.top, closeTo(rim.a, 0.02));
    expect(lit.bottom, closeTo(rim.a, 0.02));
    expect(lit.side, 0);

    final dark = await _alphas(
      tester,
      GlassRimPainter(borderRadius: _radius, edge: edge),
    );
    expect(dark.side, greaterThan(0.1));
    expect(dark.top, greaterThan(0));
    expect(dark.top, lessThan(dark.side / 2));
    expect(dark.bottom, closeTo(dark.top, 0.02));
  });

  test('faded out, strokes nothing', () {
    expect(
      _strokes(
        GlassRimPainter(
          borderRadius: _radius,
          rim: const Color(0xE6FFFFFF),
          edge: const Color(0x1F000000),
          opacity: 0,
        ),
      ),
      isEmpty,
    );
  });

  group('on a glass surface', () {
    testWidgets('rim off leaves the hairline alone', (tester) async {
      await tester.pumpWidget(_surface(rim: false));
      expect(_rimOf(tester).rim, isNull);
      expect(_rimOf(tester).edge, isNotNull);
    });

    testWidgets('the whole rim fades with the strength', (tester) async {
      await tester.pumpWidget(_surface(strength: 0.4));
      expect(_rimOf(tester).opacity, 0.4);
      expect(_rimOf(tester).rim, GlassThemeData.light().rim);
    });

    testWidgets('at strength 0 no rim is painted', (tester) async {
      await tester.pumpWidget(_surface(strength: 0));
      expect(_rims(tester), isEmpty);
    });
  });
}
