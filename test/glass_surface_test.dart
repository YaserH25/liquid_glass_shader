import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_shader/liquid_glass_shader.dart';

// Widget tests run without Impeller, so the best tier here is the blur.

final _light = GlassThemeData.light();

Widget _app(
  Widget child, {
  GlassStyle style = GlassStyle.clear,
  GlassThemeData? theme,
  bool highContrast = false,
  bool scoped = true,
  Brightness brightness = Brightness.light,
}) {
  final body = Center(child: SizedBox(width: 200, height: 60, child: child));
  return MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: MediaQuery(
      data: MediaQueryData(highContrast: highContrast),
      child: scoped
          ? GlassScope(style: style, theme: theme, child: body)
          : body,
    ),
  );
}

const _glass = GlassSurface(child: SizedBox.expand());

Iterable<BackdropFilterLayer> _backdrops(WidgetTester tester) =>
    tester.layers.whereType<BackdropFilterLayer>();

/// The tint the surface lays over its backdrop.
Color? _tint(WidgetTester tester) {
  final boxes = tester.widgetList<DecoratedBox>(
    find.descendant(
      of: find.byType(GlassSurface),
      matching: find.byType(DecoratedBox),
    ),
  );
  for (final box in boxes) {
    final decoration = box.decoration;
    if (decoration is BoxDecoration &&
        decoration.color != null &&
        decoration.gradient == null) {
      return decoration.color;
    }
  }
  return null;
}

void main() {
  group('quality tiers', () {
    testWidgets('without the shader, glass is a frosted blur', (tester) async {
      await tester.pumpWidget(_app(_glass));
      expect(_backdrops(tester), hasLength(1));
      expect(_tint(tester), _light.clear.tint);
    });

    testWidgets('high contrast makes glass opaque, with no backdrop', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_glass, highContrast: true));
      expect(_backdrops(tester), isEmpty);
      expect(_tint(tester), _light.solid);
    });

    testWidgets('after two slow windows glass turns opaque', (tester) async {
      await tester.pumpWidget(_app(_glass));
      final scope = tester.state<GlassScopeState>(find.byType(GlassScope));
      // A second of frames, all late.
      final slow = List.filled(34, (
        raster: const Duration(milliseconds: 30),
        gap: null,
      ));
      scope.recordFrames(slow, glassOnScreen: true);
      scope.recordFrames(slow, glassOnScreen: true);
      await tester.pump();

      expect(_backdrops(tester), isEmpty);
      expect(_tint(tester), _light.solid);
    });
  });

  testWidgets('shadows fall only outside the glass', (tester) async {
    await tester.pumpWidget(
      _app(
        const GlassSurface(
          shadows: [BoxShadow(blurRadius: 24, offset: Offset(0, 8))],
          child: SizedBox.expand(),
        ),
      ),
    );
    // The shadow is clipped to outside the glass: what shows through the
    // glass is the page, not the glass's own shadow.
    const size = Size(200, 60);
    final outside = [
      for (final clip in tester.widgetList<ClipPath>(
        find.descendant(
          of: find.byType(GlassSurface),
          matching: find.byType(ClipPath),
        ),
      ))
        if (clip.clipper?.getClip(size).contains(const Offset(-20, 30)) ??
            false)
          clip,
    ];
    final path = outside.single.clipper!.getClip(size);
    expect(path.contains(const Offset(100, 30)), isFalse);
    expect(path.contains(const Offset(100, 90)), isTrue);
  });

  group('looks', () {
    testWidgets('follows the style from the scope', (tester) async {
      await tester.pumpWidget(_app(_glass, style: GlassStyle.frosted));
      expect(_tint(tester), _light.frosted.tint);
    });

    testWidgets('a surface can force a style or a custom look', (tester) async {
      await tester.pumpWidget(
        _app(
          const GlassSurface(
            style: GlassStyle.frosted,
            child: SizedBox.expand(),
          ),
        ),
      );
      expect(_tint(tester), _light.frosted.tint);

      const custom = GlassLook(
        frost: 24,
        fallbackFrost: 24,
        tint: Color(0xD1F4F2EC),
        band: 20,
        bend: 8,
        dispersion: 0.05,
        specular: 0.35,
        sheen: 0.28,
      );
      await tester.pumpWidget(
        _app(
          const GlassSurface(look: custom, child: SizedBox.expand()),
          style: GlassStyle.frosted,
        ),
      );
      expect(_tint(tester), custom.tint);
    });

    testWidgets('at strength 0 nothing is drawn behind the child', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const GlassSurface(strength: 0, child: SizedBox.expand())),
      );
      expect(_backdrops(tester), isEmpty);
      expect(_tint(tester)?.a, 0);
    });

    testWidgets('without a scope, glass follows the app brightness', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(_glass, scoped: false, brightness: Brightness.dark),
      );
      expect(_tint(tester), GlassThemeData.dark().clear.tint);
      expect(_backdrops(tester), hasLength(1));
    });

    testWidgets('a new theme on the scope repaints with its tint', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_glass, theme: GlassThemeData.light()));
      expect(_tint(tester), _light.clear.tint);

      await tester.pumpWidget(_app(_glass, theme: GlassThemeData.dark()));
      expect(_tint(tester), GlassThemeData.dark().clear.tint);
    });
  });

  group('size', () {
    testWidgets('glass under one pixel draws without failing', (tester) async {
      for (final size in const [Size.zero, Size(0.5, 0.5), Size(200, 0)]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox.fromSize(size: size, child: _glass),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: '$size');
      }
    });
  });
}
