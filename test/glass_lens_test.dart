import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_shader/liquid_glass_shader.dart';

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
}
