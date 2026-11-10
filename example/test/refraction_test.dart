// The refraction shader, as Impeller draws it. Run with
//
//   flutter test --enable-impeller
//
// A plain `flutter test` has no shader filters, so these tests skip. They
// live in the example because only an app that depends on the package
// bundles the shader under the key the package loads it from.
import 'dart:math' as math;
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

/// A 300 by 60 capsule of [glass] in the middle of a page of [page], and
/// the red level of the pixel at each offset from the capsule's top left,
/// in logical pixels.
Future<List<int>> _levels(
  WidgetTester tester, {
  required Color page,
  required Widget glass,
  required List<Offset> at,
}) async {
  await tester.pumpWidget(
    RepaintBoundary(
      key: _scene,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: page,
          child: Center(
            child: SizedBox(
              width: 300,
              height: 60,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: glass,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_scene),
  );
  final origin = tester.getTopLeft(find.byType(ClipRRect));
  late List<int> levels;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _dpr);
    final bytes = (await image.toByteData())!;
    levels = [
      for (final offset in at)
        bytes.getUint8(
          (((origin.dy + offset.dy) * _dpr).round() * image.width +
                  ((origin.dx + offset.dx) * _dpr).round()) *
              4,
        ),
    ];
    image.dispose();
  });
  return levels;
}

void main() {
  testWidgets(
    'every look of the theme is the shader alone; heavy frost is the engine blur',
    (tester) async {
      _phone(tester, const Size(1170, 2532));
      await _loadShader(tester);
      Widget app(GlassStyle style, {GlassLook? look}) => MaterialApp(
        home: GlassScope(
          style: style,
          child: Center(
            child: SizedBox(
              width: 300,
              height: 60,
              child: GlassSurface(
                key: const ValueKey('glass'),
                look: look,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      final glass = find.byKey(const ValueKey('glass'));

      // A blur composed in front of a shader filter runs over the whole
      // screen: it doubled what frosted glass cost. The frost and the
      // diffusion of every look are taken in the shader instead.
      for (final style in GlassStyle.values) {
        await tester.pumpWidget(app(style));
        expect(
          GlassScope.qualityOf(tester.element(glass)),
          GlassQuality.refraction,
        );
        expect(
          '${_filterOf(tester, glass)}',
          startsWith('ImageFilter.shader'),
          reason: style.name,
        );
      }

      // A look that asks for a heavy frost still gets the engine's blur,
      // which downsamples; the shader's few taps would show.
      await tester.pumpWidget(
        app(
          GlassStyle.clear,
          look: const GlassLook(
            frost: 30,
            fallbackFrost: 30,
            tint: Color(0x9EFFFFFF),
            band: 16,
            bend: 6,
            dispersion: 0,
            specular: 0.3,
            sheen: 0,
          ),
        ),
      );
      expect('${_filterOf(tester, glass)}', startsWith('ImageFilter.compose'));
    },
    skip: !_impeller,
  );

  // The standard glass of iOS 27 keeps a third of the page sharp and
  // scatters the rest: stripes behind it keep their edges and lose two
  // thirds of their contrast.
  testWidgets('diffusion lowers contrast and keeps edges sharp', (
    tester,
  ) async {
    _phone(tester, const Size(1080, 1200));
    await _loadShader(tester);
    Widget glass(double diffusion) => GlassBackdrop(
      diffusion: diffusion,
      band: 1,
      bend: 0,
      dispersion: 0,
      specular: 0,
      radius: 0,
      child: const SizedBox.expand(),
    );
    double mean(Iterable<int> values) =>
        values.reduce((a, b) => a + b) / values.length;
    ({double dark, double light}) stripes(List<int> row) => (
      dark: mean(row.where((level) => level < 128)),
      light: mean(row.where((level) => level >= 128)),
    );

    final sharp = await _middleRow(tester, glass(0));
    expect(stripes(sharp).dark, lessThan(2));
    expect(stripes(sharp).light, greaterThan(253));

    final diffused = await _middleRow(tester, glass(2 / 3));
    final levels = stripes(diffused);
    expect(levels.light - levels.dark, closeTo(255 / 3, 8));
    // No pixel strays far from its stripe's level: a blur would leave
    // pixels half way between the two at every edge.
    for (final level in diffused) {
      final stripe = level < 128 ? levels.dark : levels.light;
      expect((level - stripe).abs(), lessThan(24));
    }
    // Each pixel turns its taps by its own angle, so the scatter shows as a
    // grain that evens out over a few pixels. With the taps in the same
    // places for every pixel it showed as ghost edges, bands several pixels
    // wide that do not even out.
    var worst = 0.0;
    for (var i = 0; i + 12 <= diffused.length; i++) {
      final window = diffused.sublist(i, i + 12);
      if (window.any((level) => level < 128) &&
          window.any((level) => level >= 128)) {
        continue;
      }
      final stripe = window.first < 128 ? levels.dark : levels.light;
      worst = math.max(worst, (mean(window) - stripe).abs());
    }
    expect(worst, lessThan(8));
  }, skip: !_impeller);

  testWidgets('the rim catches the light above and below, not at the sides', (
    tester,
  ) async {
    _phone(tester, const Size(1080, 1200));
    await _loadShader(tester);
    final [top, bottom, side, middle] = await _levels(
      tester,
      page: Colors.black,
      glass: const GlassBackdrop(
        band: 16,
        bend: 0,
        dispersion: 0,
        specular: 0.5,
        child: SizedBox.expand(),
      ),
      at: const [
        Offset(150, 0),
        Offset(150, 59.7),
        Offset(0, 30),
        Offset(150, 30),
      ],
    );
    expect(top, greaterThan(100));
    expect(bottom, closeTo(top, 6));
    expect(side, lessThan(4));
    expect(middle, 0);
  }, skip: !_impeller);

  testWidgets('dimming takes its share of the light from a white page only', (
    tester,
  ) async {
    _phone(tester, const Size(1080, 1200));
    await _loadShader(tester);
    const glass = GlassBackdrop(
      dim: 0.4,
      band: 1,
      bend: 0,
      dispersion: 0,
      specular: 0,
      child: SizedBox.expand(),
    );
    const middle = [Offset(150, 30)];
    final [white] = await _levels(
      tester,
      page: Colors.white,
      glass: glass,
      at: middle,
    );
    expect(white, closeTo(255 * 0.6, 2));
    final [grey] = await _levels(
      tester,
      page: const Color(0xFF808080),
      glass: glass,
      at: middle,
    );
    expect(grey, closeTo(128 * (1 - 0.4 * 128 / 255), 2));
  }, skip: !_impeller);

  testWidgets('the guard judges each tier by its own frames', (tester) async {
    await _loadShader(tester);
    final reported = <GlassQuality>[];
    await tester.pumpWidget(
      GlassScope(onCapChanged: reported.add, child: const SizedBox()),
    );
    final scope = tester.state<GlassScopeState>(find.byType(GlassScope));
    // Two seconds of frames, nearly all late, in one batch: the first
    // steps refraction down to the blur. The second was drawn before that
    // took effect, so it says nothing about the blur.
    final late = [
      for (var i = 0; i < 68; i++)
        (raster: const Duration(milliseconds: 30), gap: null),
    ];
    scope.recordFrames(late, glassOnScreen: true);
    expect(reported, [GlassQuality.blur]);
    expect(scope.cap, GlassQuality.blur);

    // Frames the blur drew are judged on their own.
    scope.recordFrames(late.sublist(34), glassOnScreen: true);
    expect(reported, [GlassQuality.blur, GlassQuality.solid]);
  }, skip: !_impeller);

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
