import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_shader/liquid_glass_shader.dart';

// Widget tests run without Impeller; the blur tier draws through the same
// backdrop layer, so sharing shows on its key.

/// The backdrop layers in paint order, keyed by the glass they belong to.
Map<String, BackdropKey?> _keys(WidgetTester tester) {
  final keys = <String, BackdropKey?>{};
  for (final name in ['a', 'b', 'bar']) {
    final glass = find.byKey(ValueKey('glass_$name'));
    if (glass.evaluate().isEmpty) continue;
    final layer = tester
        .renderObject<RenderGlassBackdrop>(
          find.descendant(of: glass, matching: find.byType(GlassBackdrop)),
        )
        .debugLayer;
    keys[name] = (layer as BackdropFilterLayer?)?.backdropKey;
  }
  return keys;
}

/// Draws frames for half a second, as a scroll would, so a settled page's
/// glass starts sharing. An idle screen draws no frames and needs no
/// sharing.
Future<void> _settle(WidgetTester tester) async {
  for (final ms in [100, 500, 0]) {
    tester.binding.scheduleFrame();
    await tester.pump(Duration(milliseconds: ms));
  }
}

Widget _page(String name) => Scaffold(
  body: Align(
    alignment: Alignment.topCenter,
    child: SizedBox(
      height: 56,
      child: GlassSurface(
        key: ValueKey('glass_$name'),
        shareBackdrop: true,
        child: const SizedBox.expand(),
      ),
    ),
  ),
);

void main() {
  testWidgets('glass that shares uses the scope backdrop key', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GlassScope(
          child: Column(
            children: [
              SizedBox(
                height: 56,
                child: GlassSurface(
                  key: const ValueKey('glass_a'),
                  shareBackdrop: true,
                  child: const SizedBox.expand(),
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 56,
                child: GlassSurface(
                  key: const ValueKey('glass_b'),
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await _settle(tester);
    final keys = _keys(tester);
    expect(keys['a'], isNotNull);
    expect(keys['b'], isNull);
  });

  testWidgets('without a scope nothing is shared', (tester) async {
    await tester.pumpWidget(MaterialApp(home: _page('a')));
    await _settle(tester);
    expect(_keys(tester)['a'], isNull);
  });

  testWidgets('a liquid tab bar can share', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GlassScope(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: LiquidTabBar(
              key: const ValueKey('glass_bar'),
              tabCount: 2,
              tabBuilder: (_, i, _) => Text('$i'),
              selectedIndex: 0,
              onSelected: (_) {},
              height: 56,
              shareBackdrop: true,
            ),
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(_keys(tester)['bar'], isNotNull);
  });

  // Glass sharing a backdrop sees it as it was at the first sharing glass
  // painted. A page sliding in or out is painted after the other page's
  // glass, so page glass only shares while nothing moves over its page.
  group('page glass shares only while its page is settled', () {
    late GlobalKey<NavigatorState> navigator;

    Future<void> pumpPages(WidgetTester tester) async {
      navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          builder: (context, child) => GlassScope(child: child!),
          home: _page('a'),
        ),
      );
      await _settle(tester);
    }

    testWidgets('neither page shares while one opens over the other', (
      tester,
    ) async {
      await pumpPages(tester);
      expect(_keys(tester)['a'], isNotNull);

      navigator.currentState!.push(
        MaterialPageRoute(builder: (_) => _page('b')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_keys(tester)['a'], isNull);
      expect(_keys(tester)['b'], isNull);

      await tester.pumpAndSettle();
      await _settle(tester);
      expect(_keys(tester)['b'], isNotNull);
    });

    testWidgets('neither page shares while the top one closes', (tester) async {
      await pumpPages(tester);
      navigator.currentState!.push(
        MaterialPageRoute(builder: (_) => _page('b')),
      );
      await tester.pumpAndSettle();

      navigator.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_keys(tester)['a'], isNull);
      expect(_keys(tester)['b'], isNull);

      await tester.pumpAndSettle();
      await _settle(tester);
      expect(_keys(tester)['a'], isNotNull);
    });

    testWidgets('a page waits before sharing after a sheet closes', (
      tester,
    ) async {
      await pumpPages(tester);
      showModalBottomSheet<void>(
        context: navigator.currentContext!,
        builder: (_) => const SizedBox(height: 200),
      );
      await tester.pumpAndSettle();
      navigator.currentState!.pop();
      // The sheet is still sliding down: the page must not share yet.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_keys(tester)['a'], isNull);

      await tester.pumpAndSettle();
      await _settle(tester);
      expect(_keys(tester)['a'], isNotNull);
    });

    testWidgets('a page under a sheet does not share', (tester) async {
      await pumpPages(tester);
      showModalBottomSheet<void>(
        context: navigator.currentContext!,
        builder: (_) => const SizedBox(height: 200),
      );
      await tester.pumpAndSettle();
      expect(_keys(tester)['a'], isNull);
    });
  });
}
