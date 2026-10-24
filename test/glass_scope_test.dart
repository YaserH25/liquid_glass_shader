import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_shader/liquid_glass_shader.dart';

// Widget tests run without Impeller, so the best tier here is the blur.

const _slow = Duration(milliseconds: 30);
const _fast = Duration(milliseconds: 4);

/// A frame's raster time, and the gap since the frame before it (none
/// after an idle stretch).
typedef _Frame = ({Duration raster, Duration? gap});

List<_Frame> _rasters(Iterable<Duration> rasters) => [
  for (final raster in rasters) (raster: raster, gap: null),
];

/// Frames with a short raster time, landing these gaps apart.
List<_Frame> _gaps(Iterable<Duration> gaps) => [
  for (final gap in gaps) (raster: const Duration(milliseconds: 2), gap: gap),
];

const _vsync60 = Duration(microseconds: 16667);

late BuildContext _context;

Widget _app({
  GlassGuard guard = const GlassGuard(),
  GlassQuality initialCap = GlassQuality.refraction,
  ValueChanged<GlassQuality>? onCapChanged,
  bool highContrast = false,
  bool scoped = true,
  Brightness brightness = Brightness.light,
}) {
  final probe = Builder(
    builder: (context) {
      _context = context;
      return const SizedBox.expand();
    },
  );
  return MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: MediaQuery(
      data: MediaQueryData(highContrast: highContrast),
      child: scoped
          ? GlassScope(
              guard: guard,
              initialCap: initialCap,
              onCapChanged: onCapChanged,
              child: probe,
            )
          : probe,
    ),
  );
}

GlassScopeState _scope(WidgetTester tester) =>
    tester.state<GlassScopeState>(find.byType(GlassScope));

/// One second of frames that each take [each] (at least a 60Hz frame).
List<_Frame> _second(Duration each) {
  final frame = each > _vsync60 ? each : _vsync60;
  final count =
      (const Duration(seconds: 1).inMicroseconds / frame.inMicroseconds).ceil();
  return _rasters(List.filled(count, each));
}

void main() {
  testWidgets('steps down only after two slow windows with glass shown', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    final scope = _scope(tester);

    // One slow window, then a fast one: no change.
    scope.recordFrames(_second(_slow), glassOnScreen: true);
    scope.recordFrames(_second(_fast), glassOnScreen: true);
    expect(scope.cap, GlassQuality.refraction);

    // Slow frames while no glass is shown do not count.
    scope.recordFrames(_second(_slow), glassOnScreen: false);
    scope.recordFrames(_second(_slow), glassOnScreen: false);
    expect(scope.cap, GlassQuality.refraction);

    // A slow window, a stretch without glass, another slow window: the
    // stretch resets the count.
    scope.recordFrames(_second(_slow), glassOnScreen: true);
    scope.recordFrames(const <_Frame>[], glassOnScreen: false);
    scope.recordFrames(_second(_slow), glassOnScreen: true);
    expect(scope.cap, GlassQuality.refraction);

    // Two slow windows in a row: one tier down from the tier glass is
    // actually drawn at. Without Impeller that is the blur, so the next
    // step is opaque (not a do-nothing step to blur).
    scope.recordFrames(_second(_slow), glassOnScreen: true);
    expect(scope.cap, GlassQuality.solid);
  });

  group('default guard on a 60Hz display', () {
    // 60 frames, one in [every] of them late.
    List<_Frame> frames({required int every}) => _rasters([
      for (var i = 0; i < 60; i++) i % every == every - 1 ? _slow : _fast,
    ]);

    testWidgets('steps down within two seconds of steady stutter', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      final scope = _scope(tester);
      // Two seconds of frames, 20% late.
      scope.recordFrames(frames(every: 5), glassOnScreen: true);
      scope.recordFrames(frames(every: 5), glassOnScreen: true);
      expect(scope.cap, GlassQuality.solid);
    });

    testWidgets('keeps glass when only an odd frame is late', (tester) async {
      await tester.pumpWidget(_app());
      final scope = _scope(tester);
      // Ten seconds of frames, 5% late.
      for (var i = 0; i < 10; i++) {
        scope.recordFrames(frames(every: 20), glassOnScreen: true);
      }
      expect(scope.cap, GlassQuality.refraction);
    });
  });

  // On iPhone the GPU's work does not show in raster time: a GPU-bound
  // frame has a short raster time and simply lands late.
  group('frames that land late', () {
    testWidgets('step down though raster time is short', (tester) async {
      await tester.pumpWidget(_app());
      final scope = _scope(tester);
      // One frame in five lands three vsyncs late.
      final stutter = _gaps([
        for (var i = 0; i < 60; i++)
          i % 5 == 4 ? const Duration(milliseconds: 50) : _vsync60,
      ]);
      scope.recordFrames(stutter, glassOnScreen: true);
      scope.recordFrames(stutter, glassOnScreen: true);
      expect(scope.cap, GlassQuality.solid);
    });

    testWidgets('a display slower than it reports is not slow', (tester) async {
      // Low Power Mode or mirroring run a 120Hz phone at 60Hz while it
      // still reports 120.
      tester.view.display.refreshRate = 120;
      addTearDown(tester.view.display.resetRefreshRate);
      await tester.pumpWidget(_app());
      final scope = _scope(tester);
      for (var i = 0; i < 4; i++) {
        scope.recordFrames(
          _gaps(List.filled(60, _vsync60)),
          glassOnScreen: true,
        );
      }
      expect(scope.cap, GlassQuality.refraction);
    });

    testWidgets('steadily slow frames step down', (tester) async {
      tester.view.display.refreshRate = 120;
      addTearDown(tester.view.display.resetRefreshRate);
      await tester.pumpWidget(_app());
      final scope = _scope(tester);
      // A steady 30fps on a 120Hz display.
      final slow = _gaps(List.filled(60, const Duration(microseconds: 33333)));
      scope.recordFrames(slow, glassOnScreen: true);
      scope.recordFrames(slow, glassOnScreen: true);
      expect(scope.cap, GlassQuality.solid);
    });

    testWidgets('a frame after an idle stretch is not judged', (tester) async {
      await tester.pumpWidget(_app());
      final scope = _scope(tester);
      // Taps with pauses between: the first frame after each pause has no
      // gap to judge.
      final taps = [
        for (var i = 0; i < 60; i++)
          (raster: _fast, gap: i % 5 == 0 ? null : _vsync60),
      ];
      for (var i = 0; i < 4; i++) {
        scope.recordFrames(taps, glassOnScreen: true);
      }
      expect(scope.cap, GlassQuality.refraction);
    });
  });

  // Windows are a second of frames, not a count of them: a phone that can
  // only draw a few frames a second must step down as fast as any other.
  testWidgets('a phone drawing five frames a second steps down in seconds', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    final scope = _scope(tester);
    // About 2.3 seconds of a software-rendered phone (the Android emulator
    // without a GPU took 189ms a frame).
    scope.recordFrames(
      _rasters(List.filled(12, const Duration(milliseconds: 189))),
      glassOnScreen: true,
    );
    expect(scope.cap, GlassQuality.solid);
  });

  // An app can remember the tier the guard picked, so a slow phone does not
  // stutter again on every launch.
  group('a remembered tier', () {
    testWidgets('the scope starts at the cap it is given', (tester) async {
      await tester.pumpWidget(_app(initialCap: GlassQuality.solid));
      expect(_scope(tester).cap, GlassQuality.solid);
      expect(GlassScope.qualityOf(_context), GlassQuality.solid);
    });

    testWidgets('each step down is reported', (tester) async {
      final reported = <GlassQuality>[];
      await tester.pumpWidget(_app(onCapChanged: reported.add));
      final scope = _scope(tester);
      scope.recordFrames(_second(_slow), glassOnScreen: true);
      scope.recordFrames(_second(_slow), glassOnScreen: true);
      expect(reported, [GlassQuality.solid]);
    });
  });

  testWidgets('a disabled guard never steps down', (tester) async {
    await tester.pumpWidget(_app(guard: const GlassGuard(enabled: false)));
    final scope = _scope(tester);
    for (var i = 0; i < 4; i++) {
      scope.recordFrames(_second(_slow), glassOnScreen: true);
    }
    expect(scope.cap, GlassQuality.refraction);
  });

  testWidgets('a custom window and share decide when it steps down', (
    tester,
  ) async {
    const guard = GlassGuard(
      window: Duration(milliseconds: 200),
      lateShare: 0.5,
    );
    // Ten frames 20ms apart, [slow] of them with a late raster time.
    List<_Frame> window(int slow) => [
      for (var i = 0; i < 10; i++)
        (
          raster: i < slow ? _slow : _fast,
          gap: const Duration(milliseconds: 20),
        ),
    ];

    await tester.pumpWidget(_app(guard: guard));
    var scope = _scope(tester);
    scope.recordFrames(window(6), glassOnScreen: true);
    scope.recordFrames(window(6), glassOnScreen: true);
    expect(scope.cap, GlassQuality.solid);

    // A fresh scope: exactly the share late is not slow.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app(guard: guard));
    scope = _scope(tester);
    scope.recordFrames(window(5), glassOnScreen: true);
    scope.recordFrames(window(5), glassOnScreen: true);
    expect(scope.cap, GlassQuality.refraction);
  });

  testWidgets('high contrast is solid', (tester) async {
    await tester.pumpWidget(_app(highContrast: true));
    expect(GlassScope.qualityOf(_context), GlassQuality.solid);
  });

  testWidgets('without Impeller the best tier is blur', (tester) async {
    await tester.pumpWidget(_app());
    expect(GlassScope.qualityOf(_context), GlassQuality.blur);
  });

  testWidgets('without a scope: clear style and the app brightness theme', (
    tester,
  ) async {
    await tester.pumpWidget(_app(scoped: false, brightness: Brightness.dark));
    expect(GlassScope.styleOf(_context), GlassStyle.clear);
    expect(GlassScope.themeOf(_context), GlassThemeData.dark());
  });

  testWidgets('without a scope or a Material theme: the platform brightness', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(platformBrightness: Brightness.dark),
        child: Builder(
          builder: (context) {
            _context = context;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(GlassScope.themeOf(_context), GlassThemeData.dark());
  });

  test('themes compare by value', () {
    expect(GlassThemeData.light(), GlassThemeData.light());
    expect(GlassThemeData.light(), isNot(GlassThemeData.dark()));
  });
}
