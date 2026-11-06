import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_shader/liquid_glass_shader.dart';
import 'package:liquid_glass_shader/src/active_glass.dart';

// The guard judges a frame only when glass drew a backdrop in it, so jank
// on a page without glass never costs another page its glass.

Widget _glassPage() => const Scaffold(
  body: Center(
    child: SizedBox(
      width: 200,
      height: 60,
      child: GlassSurface(child: SizedBox.expand()),
    ),
  ),
);

void main() {
  testWidgets('glass on screen draws a backdrop', (tester) async {
    expect(glassOnScreen, isFalse);
    await tester.pumpWidget(MaterialApp(home: _glassPage()));
    expect(glassOnScreen, isTrue);

    await tester.pumpWidget(const SizedBox());
    expect(glassOnScreen, isFalse);
    expect(attachedGlass, isEmpty);
  });

  testWidgets('glass on a page covered by another is not on screen', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigator, home: _glassPage()),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold()),
    );
    await tester.pumpAndSettle();
    // Still attached, kept for when the page comes back, but not painted.
    expect(attachedGlass, isNotEmpty);
    expect(glassOnScreen, isFalse);

    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(glassOnScreen, isTrue);
  });

  testWidgets('glass under Offstage is not on screen', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Offstage(child: _glassPage())));
    expect(attachedGlass, isNotEmpty);
    expect(glassOnScreen, isFalse);
  });

  testWidgets('solid glass draws no backdrop', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(highContrast: true),
          child: _glassPage(),
        ),
      ),
    );
    expect(glassOnScreen, isFalse);
  });
}
