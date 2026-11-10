// What glass adds to a frame, drawn by Impeller's software renderer, which
// pays for every pixel the way a weak GPU does. Run with
//
//   GLASS_BENCH=1 flutter test --enable-impeller test/glass_bench_test.dart
//
// Each line is the median time to draw and read back a 1080 by 2340 frame.
// Times move with whatever else the machine is doing: compare two versions
// in turn, several times each, by their fastest runs. Set GLASS_BENCH_DUMP
// to a folder to keep a picture of each scene.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_shader/liquid_glass_shader.dart';
import 'package:liquid_glass_shader_example/colorful_backdrop.dart';

final _run =
    ui.ImageFilter.isShaderFilterSupported &&
    Platform.environment.containsKey('GLASS_BENCH');
final _scene = GlobalKey();

Future<void> _loadShader(WidgetTester tester) async {
  await tester.runAsync(() async {
    LiquidGlassShader.ensureLoaded();
    for (var i = 0; i < 100 && !LiquidGlassShader.isReady; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  });
}

Widget _app({
  required GlassStyle style,
  required GlassQuality cap,
  required bool bar,
}) => RepaintBoundary(
  key: _scene,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    home: GlassScope(
      style: style,
      initialCap: cap,
      guard: const GlassGuard(enabled: false),
      child: Scaffold(
        body: Stack(
          children: [
            const ColorfulBackdrop(
              header: SizedBox.shrink(),
              padding: EdgeInsets.fromLTRB(16, 60, 16, 120),
            ),
            if (bar)
              Positioned(
                left: 21,
                right: 21,
                bottom: 21,
                child: LiquidTabBar(
                  tabCount: 4,
                  selectedIndex: 0,
                  onSelected: (_) {},
                  onTick: null,
                  tabBuilder: (context, index, active) => Icon(
                    Icons.home_rounded,
                    color: active ? Colors.indigo : Colors.black54,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  ),
);

Future<double> _frameMs(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_scene),
  );
  final times = <double>[];
  await tester.runAsync(() async {
    for (var i = 0; i < 9; i++) {
      final watch = Stopwatch()..start();
      final image = await boundary.toImage(pixelRatio: 3);
      await image.toByteData();
      times.add(watch.elapsedMicroseconds / 1000);
      if (i == 8 && Platform.environment['GLASS_BENCH_DUMP'] != null) {
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          '${Platform.environment['GLASS_BENCH_DUMP']}/'
          '${name.replaceAll(RegExp('[ ,]+'), '_')}.png',
        ).writeAsBytesSync(png!.buffer.asUint8List());
      }
      image.dispose();
    }
  });
  times.sort();
  return times[times.length ~/ 2];
}

void main() {
  testWidgets('what the tab bar adds to a frame', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await _loadShader(tester);

    Future<double> measure(
      String name, {
      GlassStyle style = GlassStyle.clear,
      GlassQuality cap = GlassQuality.refraction,
      bool bar = true,
      bool held = false,
    }) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_app(style: style, cap: cap, bar: bar));
      await tester.pump();
      TestGesture? finger;
      if (held) {
        finger = await tester.startGesture(
          tester.getCenter(find.byType(LiquidTabBar)),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }
      final ms = await _frameMs(tester, name);
      await finger?.up();
      await tester.pump(const Duration(seconds: 1));
      // ignore: avoid_print
      print('${name.padRight(28)} ${ms.toStringAsFixed(1)} ms');
      return ms;
    }

    await measure('page only', bar: false);
    for (final style in GlassStyle.values) {
      await measure('refraction, ${style.name}', style: style);
      await measure(
        'refraction, ${style.name}, held',
        style: style,
        held: true,
      );
      await measure(
        'blur, ${style.name}',
        style: style,
        cap: GlassQuality.blur,
      );
    }
    await measure('solid', cap: GlassQuality.solid);
  }, skip: !_run);
}
