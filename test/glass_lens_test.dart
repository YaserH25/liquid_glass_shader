import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_shader/liquid_glass_shader.dart';
import 'package:liquid_glass_shader/src/tab_bar/lifted_lens.dart';
import 'package:liquid_glass_shader/src/tab_bar/resting_lens_row.dart';

/// The lens's fill colour.
Color? _fill(WidgetTester tester) {
  for (final box in tester.widgetList<DecoratedBox>(
    find.descendant(
      of: find.byType(GlassLens),
      matching: find.byType(DecoratedBox),
    ),
  )) {
    final decoration = box.decoration;
    if (decoration is BoxDecoration && decoration.color != null) {
      return decoration.color;
    }
  }
  return null;
}

Widget _lens(double lift) => MaterialApp(
  home: Center(
    child: SizedBox(width: 100, height: 60, child: GlassLens(lift: lift)),
  ),
);

void main() {
  final theme = GlassThemeData.light();

  testWidgets('the resting lens uses the theme lens tint', (tester) async {
    await tester.pumpWidget(_lens(0));
    expect(_fill(tester), theme.lensTint);
  });

  testWidgets('the lifted lens clears toward the rim colour', (tester) async {
    await tester.pumpWidget(_lens(1));
    expect(_fill(tester), theme.rim.withValues(alpha: 0.12));
  });

  testWidgets('a tint and shadows of its own override the theme', (
    tester,
  ) async {
    const tint = Color(0x5534C759);
    const shadows = [BoxShadow(color: Color(0x33000000), blurRadius: 3)];
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 100,
            height: 60,
            child: GlassLens(tint: tint, shadows: shadows),
          ),
        ),
      ),
    );
    expect(_fill(tester), tint);
    final shadow = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(GlassLens),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => (box.decoration as BoxDecoration).boxShadow)
        .firstWhere((s) => s != null);
    expect(shadow, shadows);
  });

  group('fading', () {
    Widget lens(double opacity) => MaterialApp(
      home: Center(
        child: SizedBox(
          width: 100,
          height: 60,
          child: GlassLens(opacity: opacity),
        ),
      ),
    );

    testWidgets('fades its tint and shadow by their colours', (tester) async {
      await tester.pumpWidget(lens(0.5));
      expect(
        _fill(tester),
        theme.lensTint.withValues(alpha: theme.lensTint.a * 0.5),
      );
      final shadow = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(GlassLens),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((box) => (box.decoration as BoxDecoration).boxShadow)
          .firstWhere((s) => s != null && s.isNotEmpty)!
          .single;
      final rest = theme.lensShadows.single;
      expect(shadow.color.a, closeTo(rest.color.a * 0.5, 1e-6));
      expect(shadow.blurRadius, rest.blurRadius);
    });

    testWidgets('fading costs no offscreen layer', (tester) async {
      await tester.pumpWidget(lens(0.5));
      expect(
        tester.layers.whereType<OpacityLayer>().where((l) => l.alpha! < 255),
        isEmpty,
      );
    });

    testWidgets('draws nothing when it has faded out', (tester) async {
      await tester.pumpWidget(lens(0));
      expect(
        find.descendant(
          of: find.byType(GlassLens),
          matching: find.byType(DecoratedBox),
        ),
        findsNothing,
      );
    });
  });

  // With the shader, the resting lens fades out as the clear lifted lens
  // fades in over it. Through an Opacity each would cost an offscreen pass
  // every frame of the lift and the drop.
  testWidgets('the lenses cross-fade without offscreen layers', (tester) async {
    const row = Size(400, 60);
    const lens = Rect.fromLTWH(100, 0, 100, 60);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox.fromSize(
            size: row,
            child: Stack(
              children: [
                const RestingLensRow(
                  lens: lens,
                  lift: 0.5,
                  refracts: true,
                  optics: LiquidTabBarLens.standard,
                  focusRing: null,
                  tabs: SizedBox.expand(),
                ),
                const LiftedLens(
                  lens: lens,
                  row: row,
                  lift: 0.5,
                  refracts: true,
                  optics: LiquidTabBarLens.standard,
                  tabs: SizedBox.expand(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(
      tester.layers.whereType<OpacityLayer>().where((l) => l.alpha! < 255),
      isEmpty,
    );
    // Both are there, half faded.
    expect(find.byType(GlassLens), findsNWidgets(2));
  });
}
