// The refraction shader, as Impeller draws it. Run with
//
//   flutter test --enable-impeller
//
// A plain `flutter test` has no shader filters, so these tests skip. They
// live in the example because only an app that depends on the package
// bundles the shader under the key the package loads it from.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_shader/liquid_glass_shader.dart';

const _dpr = 3.0;
final _impeller = ui.ImageFilter.isShaderFilterSupported;
final _scene = GlobalKey();

/// Loads the shader; the test zone's fake clock would never finish it.
Future<void> _loadShader(WidgetTester tester) async {
  await tester.runAsync(() async {
    LiquidGlassShader.ensureLoaded();
    for (var i = 0; i < 100 && !LiquidGlassShader.isReady; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  });
  expect(LiquidGlassShader.isReady, isTrue);
}

void _phone(WidgetTester tester, Size physical) {
  tester.view.physicalSize = physical;
  tester.view.devicePixelRatio = _dpr;
  addTearDown(tester.view.reset);
}

/// The filter the glass under [glass] pushes this frame.
ui.ImageFilter? _filterOf(WidgetTester tester, Finder glass) =>
    (tester
                .renderObject<RenderGlassBackdrop>(
                  find.descendant(
                    of: glass,
                    matching: find.byType(GlassBackdrop),
                  ),
                )
                .debugLayer
            as BackdropFilterLayer?)
        ?.filter;

/// Black and white stripes, 18 logical pixels wide, under a 200 high
/// [glass] across the middle.
Widget _stripes(Widget glass) => RepaintBoundary(
  key: _scene,
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Stack(
      children: [
        Positioned.fill(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < 20; i++)
                Expanded(
                  child: ColoredBox(
                    color: i.isEven ? Colors.black : Colors.white,
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          left: 40,
          right: 40,
          top: 100,
          height: 200,
          child: ClipRect(child: glass),
        ),
      ],
    ),
  ),
);

/// The grey levels along the middle row of the glass, away from its ends.
Future<List<int>> _middleRow(WidgetTester tester, Widget glass) async {
  await tester.pumpWidget(_stripes(glass));
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_scene),
  );
  late List<int> row;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _dpr);
    final bytes = (await image.toByteData())!;
    final y = (200 * _dpr).round();
    row = [
      for (var x = (60 * _dpr).round(); x < image.width - 60 * _dpr; x++)
        bytes.getUint8((y * image.width + x) * 4), // red
    ];
    image.dispose();
  });
  return row;
}

/// The mean width over which the row rises from 10% to 90% at its dark to
/// light edges: how far a frost spreads an edge.
double _riseWidth(List<int> row) {
  final widths = <int>[];
  for (var i = 1; i < row.length; i++) {
    if (row[i - 1] >= 128 || row[i] < 128) continue;
    var low = i, high = i;
    while (low > 0 && row[low] > 0.1 * 255) {
      low--;
    }
    while (high < row.length - 1 && row[high] < 0.9 * 255) {
      high++;
    }
    widths.add(high - low);
  }
  return widths.reduce((a, b) => a + b) / widths.length;
}

void main() {
  testWidgets(
    'the clear look frosts in the shader; heavy frost is the engine blur',
    (tester) async {
      _phone(tester, const Size(1170, 2532));
      await _loadShader(tester);
      Widget app(GlassStyle style) => MaterialApp(
        home: GlassScope(
          style: style,
          child: const Center(
            child: SizedBox(
              width: 300,
              height: 60,
              child: GlassSurface(
                key: ValueKey('glass'),
                child: SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      final glass = find.byKey(const ValueKey('glass'));

      // A blur composed in front of a shader filter runs over the whole
      // screen at full resolution; the clear look's light frost must not.
      await tester.pumpWidget(app(GlassStyle.clear));
      expect(
        GlassScope.qualityOf(tester.element(glass)),
        GlassQuality.refraction,
      );
      expect('${_filterOf(tester, glass)}', startsWith('ImageFilter.shader'));

      // Heavy frost downsamples, so the engine's blur stays cheap.
      await tester.pumpWidget(app(GlassStyle.frosted));
      expect('${_filterOf(tester, glass)}', startsWith('ImageFilter.compose'));
    },
    skip: !_impeller,
  );

  testWidgets("the shader's frost spreads an edge as the engine's blur does", (
    tester,
  ) async {
    _phone(tester, const Size(1080, 1200));
    await _loadShader(tester);
    for (final sigma in [0.5, 1.0, 1.5, 2.0]) {
      final engine = await _middleRow(
        tester,
        BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: const SizedBox.expand(),
        ),
      );
      // Flat glass with nothing but frost.
      final shader = await _middleRow(
        tester,
        GlassBackdrop(
          frost: sigma,
          band: 1,
          bend: 0,
          dispersion: 0,
          specular: 0,
          radius: 0,
          child: const SizedBox.expand(),
        ),
      );
      expect(
        _riseWidth(shader),
        closeTo(_riseWidth(engine), 1.5),
        reason: 'sigma $sigma',
      );
      var difference = 0;
      for (var i = 0; i < engine.length; i++) {
        difference += (engine[i] - shader[i]).abs();
      }
      expect(difference / engine.length, lessThan(8), reason: 'sigma $sigma');
    }
  }, skip: !_impeller);
}
