import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_shader/liquid_glass_shader.dart';

final _motion = LiquidTabBarMotion.standard;
const _lens = LiquidTabBarLens.standard;

/// A 76 high bar that fills its width, as wide as the row of tabs is.
const _metrics = LiquidTabBarMetrics(thickness: 76, tabExtent: double.infinity);

/// The bar is 408 wide; inside the glass's 4dp inset each tab is 100 wide.
class _Harness extends StatefulWidget {
  const _Harness({
    required this.initial,
    required this.selections,
    this.direction = TextDirection.ltr,
    this.reduceMotion = false,
  });

  final int initial;
  final List<int> selections;
  final TextDirection direction;
  final bool reduceMotion;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late int selected = widget.initial;

  void select(int index) => setState(() => selected = index);

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: widget.reduceMotion),
      child: Directionality(
        textDirection: widget.direction,
        child: Center(
          child: SizedBox(
            width: 408,
            child: LiquidTabBar(
              tabCount: 4,
              tabBuilder: (_, i, _) => Center(child: Text('ABCD'[i])),
              selectedIndex: selected,
              metrics: _metrics,
              onSelected: (index) {
                widget.selections.add(index);
                select(index);
              },
            ),
          ),
        ),
      ),
    ),
  );
}

Future<List<int>> _pump(
  WidgetTester tester, {
  int selected = 0,
  TextDirection direction = TextDirection.ltr,
  bool reduceMotion = false,
}) async {
  final selections = <int>[];
  await tester.pumpWidget(
    _Harness(
      initial: selected,
      selections: selections,
      direction: direction,
      reduceMotion: reduceMotion,
    ),
  );
  return selections;
}

final _restingLens = find.byKey(const Key('liquid_tab_bar_lens'));
final _liftedLens = find.byKey(const Key('liquid_tab_bar_lifted_lens'));

/// Lets animations run for [ms]. The first frame only starts them.
Future<void> _advance(WidgetTester tester, int ms) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
}

Finder _tab(int i) => find.byKey(Key('liquid_tab_$i'));

/// Left edge of the row of tabs, in physical terms.
double _rowLeft(WidgetTester tester) =>
    [for (var i = 0; i < 4; i++) tester.getRect(_tab(i)).left]
        .reduce((a, b) => a < b ? a : b);

/// Records haptic calls sent to the platform.
List<String> _recordHaptics(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add(call.arguments as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return calls;
}

void main() {
  group('at rest', () {
    testWidgets('the lens sits under the selected tab, from the start edge', (
      tester,
    ) async {
      await _pump(tester, selected: 1);
      final left = _rowLeft(tester);
      expect(tester.getRect(_restingLens).left, left + 100);
      expect(tester.getRect(_restingLens).width, 100);

      await _pump(tester, selected: 1, direction: TextDirection.rtl);
      await tester.pumpAndSettle();
      // In RTL, tab 1 is the second from the right.
      expect(tester.getRect(_restingLens).left, left + 200);
    });

    testWidgets('a tab change from elsewhere slides and stretches the lens', (
      tester,
    ) async {
      await _pump(tester);
      tester.state<_HarnessState>(find.byType(_Harness)).select(2);
      // 120Hz frames through the first part of the slide.
      var widest = 0.0;
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 8));
        widest = math.max(widest, tester.getRect(_restingLens).width);
      }
      // Mid-move: drawn out along its path, like a droplet.
      expect(widest, greaterThan(110));

      await tester.pumpAndSettle();
      expect(tester.getRect(_restingLens).left, _rowLeft(tester) + 200);
      expect(tester.getRect(_restingLens).width, 100);
    });

    testWidgets('reduced motion moves the lens at once', (tester) async {
      await _pump(tester, reduceMotion: true);
      tester.state<_HarnessState>(find.byType(_Harness)).select(3);
      await tester.pump();
      expect(tester.getRect(_restingLens).left, _rowLeft(tester) + 300);
      expect(tester.getRect(_restingLens).width, 100);
    });
  });

  group('press', () {
    testWidgets('lifts the lens under the finger and swells the bar; '
        'the tab changes only on release', (tester) async {
      final selections = await _pump(tester);
      final restingBar = tester.getRect(find.byType(GlassSurface));

      final gesture = await tester.startGesture(tester.getCenter(_tab(2)));
      await _advance(tester, 400);

      expect(_restingLens, findsNothing);
      final lens = tester.getRect(_liftedLens);
      expect(lens.center.dx, closeTo(tester.getCenter(_tab(2)).dx, 1));
      // Larger than the tab, and taller than the bar: it stands over it.
      expect(
        lens.width,
        closeTo(100 * _lens.liftedExtent * _motion.pressedScale, 2),
      );
      expect(lens.height, greaterThan(restingBar.height));
      expect(
        tester.getRect(find.byType(GlassSurface)).width,
        closeTo(restingBar.width * _motion.pressedScale, 1),
      );
      expect(selections, isEmpty);

      await gesture.up();
      expect(selections, [2]);
      await tester.pumpAndSettle();
      expect(_liftedLens, findsNothing);
      expect(tester.getRect(_restingLens).left, _rowLeft(tester) + 200);
      expect(tester.getRect(find.byType(GlassSurface)), restingBar);
    });

    testWidgets('magnifies the tabs inside the lifted lens', (tester) async {
      await _pump(tester);
      final gesture = await tester.startGesture(tester.getCenter(_tab(1)));
      await _advance(tester, 400);

      final inLens = find.descendant(of: _liftedLens, matching: find.text('B'));
      final inBar = find.descendant(of: _tab(1), matching: find.text('B'));
      // Bar swell × lens magnification against the bar's own label.
      expect(
        tester.getRect(inLens).width / tester.getRect(inBar).width,
        closeTo(_lens.magnification, 0.01),
      );
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a tap on the current tab reselects it without a tick', (
      tester,
    ) async {
      final haptics = _recordHaptics(tester);
      final selections = await _pump(tester, selected: 1);
      await tester.tap(_tab(1));
      await tester.pumpAndSettle();
      expect(selections, [1]);
      expect(haptics, isEmpty);
    });

    testWidgets('after release the lens drops once and never lifts again', (
      tester,
    ) async {
      await _pump(tester);
      final gesture = await tester.startGesture(tester.getCenter(_tab(2)));
      await _advance(tester, 400);
      await gesture.up();

      var dropped = false;
      for (var frame = 0; frame < 60; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        final liftedNow = _liftedLens.evaluate().isNotEmpty;
        if (!liftedNow) dropped = true;
        expect(
          dropped && liftedNow,
          isFalse,
          reason: 'lifted again at frame $frame',
        );
      }
      expect(dropped, isTrue);
    });

    testWidgets('a cancelled touch leaves the selection alone', (tester) async {
      final selections = await _pump(tester);
      final gesture = await tester.startGesture(tester.getCenter(_tab(3)));
      await _advance(tester, 200);
      await gesture.cancel();
      await tester.pumpAndSettle();

      expect(selections, isEmpty);
      expect(tester.getRect(_restingLens).left, _rowLeft(tester));
    });
  });

  group('drag', () {
    Future<void> scrub(WidgetTester tester, List<int> through) async {
      final gesture = await tester.startGesture(
        tester.getCenter(_tab(through.first)),
      );
      await _advance(tester, 100);
      for (final i in through.skip(1)) {
        await gesture.moveTo(tester.getCenter(_tab(i)));
        await _advance(tester, 100);
      }
      // Lets go nearer the last tab than its neighbour.
      await gesture.moveBy(const Offset(20, 0));
      await _advance(tester, 100);
      await gesture.up();
    }

    testWidgets('the lens follows the finger and snaps to the nearest tab', (
      tester,
    ) async {
      final haptics = _recordHaptics(tester);
      final selections = await _pump(tester);
      final left = _rowLeft(tester);

      final gesture = await tester.startGesture(tester.getCenter(_tab(0)));
      await _advance(tester, 300);
      await gesture.moveBy(const Offset(140, 0));
      await _advance(tester, 300);
      // Between tabs 1 and 2, under the finger; nothing selected yet.
      expect(
        tester.getRect(_liftedLens).center.dx,
        closeTo(left + 50 + 140, 2),
      );
      expect(selections, isEmpty);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(selections, [1]);
      expect(haptics, ['HapticFeedbackType.selectionClick']);
      expect(tester.getRect(_restingLens).left, left + 100);
    });

    testWidgets('once under the finger, the lens keeps up with it each frame', (
      tester,
    ) async {
      await _pump(tester);
      final start = tester.getCenter(_tab(0));
      final gesture = await tester.startGesture(start);
      await _advance(tester, 300);

      var fingerX = start.dx;
      for (final step in [60.0, 45.0, 80.0]) {
        await gesture.moveBy(Offset(step, 0));
        fingerX += step;
        await tester.pump();
        // Same frame as the move: no spring trailing behind the finger.
        expect(tester.getRect(_liftedLens).center.dx, closeTo(fingerX, 1));
      }
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('keeps up with a fast drag from touch-down (120Hz input)', (
      tester,
    ) async {
      await _pump(tester);
      final start = tester.getCenter(_tab(0));
      final gesture = await tester.startGesture(start);
      // A real touchscreen sends a move before every frame. Drag 300px over
      // 300ms, one move and one 8ms frame at a time, starting at once.
      var fingerX = start.dx;
      for (var i = 0; i < 38; i++) {
        await gesture.moveBy(const Offset(8, 0));
        fingerX += 8;
        await tester.pump(const Duration(milliseconds: 8));
      }
      // Caught up with the finger shortly after touch-down, and stays with
      // it (within a frame of travel).
      expect(tester.getRect(_liftedLens).center.dx, closeTo(fingerX, 10));
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('stretches like a drop while swiping, then rounds out', (
      tester,
    ) async {
      await _pump(tester);
      final gesture = await tester.startGesture(tester.getCenter(_tab(0)));
      await _advance(tester, 400);
      final held = tester.getRect(_liftedLens).width;

      // A brisk swipe: 12px a frame at 120Hz (about 1500px/s).
      var widest = held;
      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(const Offset(12, 0));
        await tester.pump(const Duration(milliseconds: 8));
        widest = math.max(widest, tester.getRect(_liftedLens).width);
      }
      expect(widest, greaterThan(held * 1.1));

      // The finger stops: the drop rounds out again.
      await _advance(tester, 600);
      expect(tester.getRect(_liftedLens).width, closeTo(held, 2));
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a finger resting on the bar lets frames stop', (tester) async {
      await _pump(tester);
      final gesture = await tester.startGesture(tester.getCenter(_tab(0)));
      await _advance(tester, 2000);

      // Nothing moves under a still finger, so nothing asks for frames.
      expect(tester.binding.transientCallbackCount, 0);

      // Moving again still draws the drop out.
      final held = tester.getRect(_liftedLens).width;
      var widest = held;
      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(const Offset(12, 0));
        await tester.pump(const Duration(milliseconds: 8));
        widest = math.max(widest, tester.getRect(_liftedLens).width);
      }
      expect(widest, greaterThan(held * 1.1));
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('moving within one tab does not rebuild the tabs', (
      tester,
    ) async {
      var builds = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 408,
              child: LiquidTabBar(
                tabCount: 4,
                tabBuilder: (_, i, _) {
                  builds++;
                  return Center(child: Text('ABCD'[i]));
                },
                selectedIndex: 0,
                metrics: _metrics,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(_tab(1)) - const Offset(30, 0),
      );
      await _advance(tester, 300);
      builds = 0;

      for (var i = 0; i < 5; i++) {
        await gesture.moveBy(const Offset(10, 0));
        await tester.pump(const Duration(milliseconds: 8));
      }

      expect(builds, 0);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a tap settles the lens on the new tab within 300ms', (
      tester,
    ) async {
      await _pump(tester);
      final left = _rowLeft(tester);
      await tester.tap(_tab(2));
      await _advance(tester, 300);

      final lens = _liftedLens.evaluate().isNotEmpty
          ? tester.getRect(_liftedLens)
          : tester.getRect(_restingLens);
      expect(lens.center.dx, closeTo(left + 250, 2));
      expect(lens.width, closeTo(100, 3));
      await tester.pumpAndSettle();
    });

    testWidgets('ticks once per tab crossed and selects only on release', (
      tester,
    ) async {
      final haptics = _recordHaptics(tester);
      final selections = await _pump(tester);
      await scrub(tester, [0, 1, 2, 3, 2]);
      await tester.pumpAndSettle();

      expect(selections, [2]);
      expect(haptics, List.filled(4, 'HapticFeedbackType.selectionClick'));
      expect(tester.getRect(_restingLens).left, _rowLeft(tester) + 200);
    });

    testWidgets('scrubs in RTL from the right edge', (tester) async {
      final selections = await _pump(tester, direction: TextDirection.rtl);
      final left = _rowLeft(tester);
      // Tab 0 is rightmost in RTL.
      expect(tester.getRect(_restingLens).left, left + 300);

      await scrub(tester, [0, 1, 2]);
      await tester.pumpAndSettle();

      expect(selections, [2]);
      expect(tester.getRect(_restingLens).left, left + 100);
    });

    testWidgets('resists being pulled past the last tab', (tester) async {
      await _pump(tester, selected: 3);
      final left = _rowLeft(tester);
      final gesture = await tester.startGesture(tester.getCenter(_tab(3)));
      await gesture.moveBy(const Offset(300, 0));
      await _advance(tester, 400);

      // Measured against the swollen bar's last tab.
      final pastLast =
          tester.getRect(_liftedLens).center.dx - tester.getCenter(_tab(3)).dx;
      expect(pastLast, greaterThan(0));
      expect(
        pastLast,
        lessThanOrEqualTo(100 * _motion.rubberBand * _motion.pressedScale),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.getRect(_restingLens).left, left + 300);
    });

    testWidgets('reduced motion keeps the lens flat and moves it tab by tab', (
      tester,
    ) async {
      final selections = await _pump(tester, reduceMotion: true);
      final left = _rowLeft(tester);

      final gesture = await tester.startGesture(tester.getCenter(_tab(0)));
      await gesture.moveBy(const Offset(140, 0));
      await tester.pump();
      expect(_liftedLens, findsNothing);
      expect(tester.getRect(_restingLens).left, left + 100);
      expect(tester.getRect(_restingLens).width, 100);

      await gesture.up();
      await tester.pump();
      expect(selections, [1]);
      expect(tester.getRect(_restingLens).left, left + 100);
    });
  });

  group('sizes', () {
    /// A bar in a 408-wide space over a page that counts the taps reaching
    /// it.
    Future<List<String>> pumpSized(
      WidgetTester tester, {
      LiquidTabBarMetrics metrics = LiquidTabBarMetrics.stacked,
      AlignmentGeometry alignment = Alignment.center,
      AlignmentGeometry minimizedAlignment = AlignmentDirectional.bottomStart,
      bool minimized = false,
      TextDirection direction = TextDirection.ltr,
    }) async {
      final calls = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: direction,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => calls.add('page'),
                  ),
                ),
                Center(
                  child: SizedBox(
                    width: 408,
                    child: LiquidTabBar(
                      tabCount: 4,
                      tabBuilder: (_, i, _) => Center(child: Text('ABCD'[i])),
                      selectedIndex: 0,
                      metrics: metrics,
                      alignment: alignment,
                      minimized: minimized,
                      minimizedAlignment: minimizedAlignment,
                      onSelected: (_) => calls.add('bar'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return calls;
    }

    Rect bar(WidgetTester tester) => tester.getRect(find.byType(LiquidTabBar));
    Rect glass(WidgetTester tester) =>
        tester.getRect(find.byType(GlassSurface));

    testWidgets('is as thick as its metrics, glass included', (tester) async {
      await pumpSized(tester, metrics: LiquidTabBarMetrics.compactInline);
      expect(bar(tester).height, 44);
      expect(glass(tester).height, 44);
    });

    testWidgets('hugs its tabs, centred, when there is room', (tester) async {
      final calls = await pumpSized(tester);
      // Four 90-long slots and the inset at both ends.
      expect(glass(tester).width, 4 * 90 + 2 * 4);
      expect(glass(tester).center, bar(tester).center);
      expect(bar(tester).width, 408);

      // Beside the glass, a touch reaches the page under the bar.
      await tester.tapAt(bar(tester).centerLeft + const Offset(10, 0));
      expect(calls, ['page']);
    });

    testWidgets('fills its width when the tabs would not fit', (tester) async {
      await pumpSized(
        tester,
        metrics: LiquidTabBarMetrics.stacked.copyWith(tabExtent: 200),
      );
      expect(glass(tester), bar(tester));
    });

    testWidgets('sits where its alignment says, in RTL too', (tester) async {
      await pumpSized(tester, alignment: AlignmentDirectional.centerStart);
      expect(glass(tester).left, bar(tester).left);
      await pumpSized(
        tester,
        alignment: AlignmentDirectional.centerStart,
        direction: TextDirection.rtl,
      );
      expect(glass(tester).right, bar(tester).right);
    });

    testWidgets('a lens gap keeps the resting lens off its slot edges', (
      tester,
    ) async {
      await pumpSized(
        tester,
        metrics: _metrics.copyWith(
          lensGap: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
      );
      final lens = tester.getRect(_restingLens);
      expect(lens.size, const Size(100 - 20, 68 - 12));
      expect(lens.center, tester.getCenter(_tab(0)));
    });

    testWidgets('rounds its corners as the metrics say, a capsule without', (
      tester,
    ) async {
      await pumpSized(tester);
      expect(
        tester.widget<GlassSurface>(find.byType(GlassSurface)).borderRadius,
        isNull,
      );
      await pumpSized(
        tester,
        metrics: LiquidTabBarMetrics.stacked.copyWith(
          borderRadius: BorderRadius.circular(16),
        ),
      );
      expect(
        tester.widget<GlassSurface>(find.byType(GlassSurface)).borderRadius,
        BorderRadius.circular(16),
      );
    });

    testWidgets('minimizes into a pill as thick as the bar, where it is told', (
      tester,
    ) async {
      await pumpSized(
        tester,
        minimized: true,
        minimizedAlignment: AlignmentDirectional.bottomEnd,
      );
      expect(glass(tester).size, const Size.square(62));
      expect(glass(tester).bottomRight, bar(tester).bottomRight);

      await pumpSized(
        tester,
        minimized: true,
        metrics: LiquidTabBarMetrics.stacked.copyWith(minimizedSize: 48),
      );
      expect(glass(tester).size, const Size.square(48));
      expect(glass(tester).bottomLeft, bar(tester).bottomLeft);
    });
  });

  group('vertical', () {
    /// A column of four tabs in a 408-high space.
    Future<List<int>> pumpColumn(
      WidgetTester tester, {
      int selected = 0,
      TextDirection direction = TextDirection.ltr,
      LiquidTabBarMetrics metrics = _metrics,
      bool minimized = false,
    }) async {
      final selections = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: direction,
            child: Center(
              child: SizedBox(
                height: 408,
                child: LiquidTabBar(
                  axis: Axis.vertical,
                  tabCount: 4,
                  tabBuilder: (_, i, _) => Center(child: Text('ABCD'[i])),
                  selectedIndex: selected,
                  metrics: metrics,
                  minimized: minimized,
                  onSelected: selections.add,
                ),
              ),
            ),
          ),
        ),
      );
      return selections;
    }

    Rect bar(WidgetTester tester) => tester.getRect(find.byType(LiquidTabBar));
    Rect glass(WidgetTester tester) =>
        tester.getRect(find.byType(GlassSurface));

    testWidgets('stands as a column, its tabs from the top in either '
        'direction', (tester) async {
      for (final direction in TextDirection.values) {
        await pumpColumn(tester, direction: direction);
        await tester.pumpAndSettle();
        expect(glass(tester).size, const Size(76, 408));
        final centres = [for (var i = 0; i < 4; i++) tester.getCenter(_tab(i))];
        for (var i = 1; i < 4; i++) {
          expect(centres[i].dy - centres[i - 1].dy, 100);
          expect(centres[i].dx, centres[0].dx);
        }
        expect(tester.getCenter(_restingLens), centres[0]);
      }
    });

    testWidgets('a finger drags the lens down and selects on release', (
      tester,
    ) async {
      final selections = await pumpColumn(tester);
      final gesture = await tester.startGesture(tester.getCenter(_tab(0)));
      await _advance(tester, 100);
      await gesture.moveTo(tester.getCenter(_tab(2)));
      await _advance(tester, 300);
      expect(
        tester.getCenter(_liftedLens).dy,
        closeTo(tester.getCenter(_tab(2)).dy, 1),
      );
      expect(selections, isEmpty);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(selections, [2]);
      expect(tester.getCenter(_restingLens), tester.getCenter(_tab(2)));
    });

    testWidgets('a slide draws the lens out down the column', (tester) async {
      await pumpColumn(tester);
      await tester.pumpAndSettle();
      await pumpColumn(tester, selected: 3);
      var longest = 0.0;
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 8));
        longest = math.max(longest, tester.getRect(_restingLens).height);
      }
      expect(longest, greaterThan(110));
      await tester.pumpAndSettle();
      expect(tester.getRect(_restingLens).height, 100);
    });

    testWidgets('hugs its tabs, and minimizes into a pill at the top', (
      tester,
    ) async {
      await pumpColumn(tester, metrics: LiquidTabBarMetrics.stacked);
      await tester.pumpAndSettle();
      expect(glass(tester).height, 4 * 90 + 2 * 4);
      expect(glass(tester).center, bar(tester).center);

      await pumpColumn(
        tester,
        metrics: LiquidTabBarMetrics.stacked,
        minimized: true,
      );
      await tester.pumpAndSettle();
      expect(glass(tester).size, const Size.square(62));
      expect(glass(tester).topCenter, bar(tester).topCenter);
    });
  });

  testWidgets('large text scales down to fit its slot, never overflowing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(3)),
          child: Center(
            child: SizedBox(
              width: 408,
              child: LiquidTabBar(
                tabCount: 4,
                tabBuilder: (_, i, _) => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [const Icon(Icons.star), Text('ABCD'[i])],
                ),
                selectedIndex: 0,
                metrics: LiquidTabBarMetrics.compactInline,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    // The label sits inside the row: the bar less its inset.
    final row = tester.getRect(find.byType(GlassSurface)).deflate(4);
    final label = tester.getRect(
      find.descendant(of: _tab(0), matching: find.text('A')),
    );
    expect(row.top, lessThanOrEqualTo(label.top));
    expect(row.bottom, greaterThanOrEqualTo(label.bottom));
  });

  group('rebuilds', () {
    // A rebuild of the bar would hand the glass a new widget; the same
    // instance frame after frame means only the lens was rebuilt.
    GlassSurface glass(WidgetTester tester) =>
        tester.widget<GlassSurface>(find.byType(GlassSurface));

    Future<void> expectGlassKept(WidgetTester tester, {int frames = 12}) async {
      final before = glass(tester);
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(identical(glass(tester), before), isTrue, reason: 'frame $i');
      }
    }

    testWidgets('a sliding lens leaves the glass alone', (tester) async {
      await _pump(tester);
      tester.state<_HarnessState>(find.byType(_Harness)).select(3);
      await tester.pump();
      await expectGlassKept(tester);
      await tester.pumpAndSettle();
    });

    testWidgets('a lifting, dragged lens leaves the glass alone', (
      tester,
    ) async {
      await _pump(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(_tab(0)) - const Offset(30, 0),
      );
      // The press marks the tab under the finger: one rebuild.
      await tester.pump();
      final before = glass(tester);
      for (var i = 0; i < 12; i++) {
        await gesture.moveBy(const Offset(4, 0));
        await tester.pump(const Duration(milliseconds: 16));
        expect(identical(glass(tester), before), isTrue, reason: 'frame $i');
      }
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('minimizing leaves the glass alone', (tester) async {
      Widget bar({required bool minimized}) => MaterialApp(
        home: Center(
          child: SizedBox(
            width: 408,
            child: LiquidTabBar(
              tabCount: 4,
              tabBuilder: (_, i, _) => Center(child: Text('ABCD'[i])),
              selectedIndex: 0,
              metrics: _metrics,
              minimized: minimized,
              onSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpWidget(bar(minimized: false));
      await tester.pumpWidget(bar(minimized: true));
      await expectGlassKept(tester);
      await tester.pumpAndSettle();
    });
  });

  testWidgets('screen readers tap a tab directly', (tester) async {
    final handle = tester.ensureSemantics();
    final selections = await _pump(tester);
    tester.semantics.tap(find.semantics.byLabel('C'));
    await tester.pumpAndSettle();
    expect(selections, [2]);
    expect(tester.getRect(_restingLens).left, _rowLeft(tester) + 200);
    handle.dispose();
  });

  group('edges', () {
    Widget plain({
      required int count,
      int selected = 0,
      TextDirection direction = TextDirection.ltr,
      double scale = 1,
      ValueChanged<int>? onTick = LiquidTabBar.selectionClick,
      List<int>? selections,
    }) => MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: Center(
          child: Transform.scale(
            scale: scale,
            child: SizedBox(
              width: 408,
              child: LiquidTabBar(
                tabCount: count,
                tabBuilder: (_, i, _) => Center(child: Text('ABCD'[i])),
                selectedIndex: selected,
                metrics: _metrics,
                onTick: onTick,
                onSelected: (index) => selections?.add(index),
              ),
            ),
          ),
        ),
      ),
    );

    testWidgets(
      'keeps the lens under the selected tab when the count changes in RTL',
      (tester) async {
        await tester.pumpWidget(
          plain(count: 4, selected: 1, direction: TextDirection.rtl),
        );
        await tester.pumpWidget(
          plain(count: 3, selected: 1, direction: TextDirection.rtl),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getCenter(_restingLens).dx,
          closeTo(tester.getCenter(_tab(1)).dx, 0.5),
        );
      },
    );

    testWidgets('tracks the finger under a scaled ancestor', (tester) async {
      final selections = <int>[];
      await tester.pumpWidget(
        plain(count: 4, scale: 0.5, selections: selections),
      );
      final gesture = await tester.startGesture(tester.getCenter(_tab(0)));
      await _advance(tester, 100);
      await gesture.moveTo(tester.getCenter(_tab(3)));
      await _advance(tester, 100);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(selections, [3]);
    });

    testWidgets(
      'tabs are buttons with the selected state and their own label',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(plain(count: 4));
        expect(
          tester.getSemantics(_tab(2)),
          matchesSemantics(
            isButton: true,
            hasSelectedState: true,
            isSelected: false,
            hasTapAction: true,
            label: 'C',
          ),
        );
        expect(
          tester.getSemantics(_tab(0)),
          matchesSemantics(
            isButton: true,
            hasSelectedState: true,
            isSelected: true,
            hasTapAction: true,
            label: 'A',
          ),
        );
        handle.dispose();
      },
    );

    Future<void> scrubAcross(WidgetTester tester) async {
      final gesture = await tester.startGesture(tester.getCenter(_tab(0)));
      await _advance(tester, 100);
      for (final i in [1, 2, 3]) {
        await gesture.moveTo(tester.getCenter(_tab(i)));
        await _advance(tester, 100);
      }
      await gesture.up();
      await tester.pumpAndSettle();
    }

    testWidgets('no haptics without onTick', (tester) async {
      final haptics = _recordHaptics(tester);
      await tester.pumpWidget(plain(count: 4, onTick: null));
      await scrubAcross(tester);
      expect(haptics, isEmpty);
    });

    testWidgets('onTick hears each tab the lens moves onto, instead of the '
        'click', (tester) async {
      final haptics = _recordHaptics(tester);
      final ticks = <int>[];
      await tester.pumpWidget(plain(count: 4, onTick: ticks.add));
      await scrubAcross(tester);
      expect(ticks, [1, 2, 3]);
      expect(haptics, isEmpty);
    });

    testWidgets('hands its glass settings to the glass', (tester) async {
      const look = GlassLook(
        frost: 4,
        fallbackFrost: 8,
        tint: Color(0x220000FF),
        band: 10,
        bend: 5,
        dispersion: 0.1,
        specular: 0.2,
        sheen: 0.1,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: LiquidTabBar(
            tabCount: 2,
            tabBuilder: (_, i, _) => Text('$i'),
            selectedIndex: 0,
            onSelected: (_) {},
            style: GlassStyle.frosted,
            look: look,
            rim: false,
            edge: false,
            strength: 0.5,
          ),
        ),
      );
      final glass = tester.widget<GlassSurface>(find.byType(GlassSurface));
      expect(glass.style, GlassStyle.frosted);
      expect(glass.look, look);
      expect(glass.rim, isFalse);
      expect(glass.edge, isFalse);
      expect(glass.strength, 0.5);
    });

    testWidgets('the lens takes the tint and shadows of its bar', (
      tester,
    ) async {
      const lens = LiquidTabBarLens(
        tint: Color(0x5534C759),
        shadows: [BoxShadow(blurRadius: 2)],
        liftedShadows: [BoxShadow(blurRadius: 9)],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: LiquidTabBar(
            tabCount: 2,
            tabBuilder: (_, i, _) => Text('$i'),
            selectedIndex: 0,
            onSelected: (_) {},
            lens: lens,
          ),
        ),
      );
      final resting = tester.widget<GlassLens>(_restingLens);
      expect(resting.tint, lens.tint);
      expect(resting.shadows, lens.shadows);
      expect(resting.liftedShadows, lens.liftedShadows);
    });

    test('rejects a selected index out of range', () {
      expect(
        () => LiquidTabBar(
          tabCount: 2,
          tabBuilder: (_, _, _) => const SizedBox(),
          selectedIndex: 2,
          onSelected: (_) {},
          metrics: _metrics,
        ),
        throwsAssertionError,
      );
    });
  });

  group('minimized', () {
    /// A 408-wide bar over a page that counts the taps that reach it.
    Future<({List<int> selections, List<String> calls})> pumpMinimizable(
      WidgetTester tester, {
      required bool minimized,
      int selected = 2,
      TextDirection direction = TextDirection.ltr,
      bool reduceMotion = false,
      bool screenReader = false,
      ({List<int> selections, List<String> calls})? record,
    }) async {
      final log = record ?? (selections: <int>[], calls: <String>[]);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              disableAnimations: reduceMotion,
              accessibleNavigation: screenReader,
            ),
            child: Directionality(
              textDirection: direction,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => log.calls.add('page'),
                    ),
                  ),
                  Center(
                    child: SizedBox(
                      width: 408,
                      child: LiquidTabBar(
                        tabCount: 4,
                        tabBuilder: (_, i, _) => Center(child: Text('ABCD'[i])),
                        minimizedBuilder: (_, i) => Text('min$i'),
                        selectedIndex: selected,
                        metrics: _metrics,
                        minimized: minimized,
                        onExpand: () => log.calls.add('expand'),
                        onSelected: log.selections.add,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return log;
    }

    Rect bar(WidgetTester tester) => tester.getRect(find.byType(LiquidTabBar));
    Rect glass(WidgetTester tester) => tester.getRect(
      find
          .descendant(
            of: find.byType(LiquidTabBar),
            matching: find.byType(GlassSurface),
          )
          .first,
    );

    testWidgets('shrinks the glass into a pill at the start edge, '
        'showing the minimized tab', (tester) async {
      await pumpMinimizable(tester, minimized: false);
      expect(glass(tester).width, 408);

      await pumpMinimizable(tester, minimized: true);
      await tester.pumpAndSettle();
      final pill = glass(tester);
      expect(pill.width, _metrics.thickness);
      expect(pill.height, _metrics.thickness);
      expect(pill.left, bar(tester).left);
      expect(pill.bottom, bar(tester).bottom);
      expect(find.text('min2').hitTestable(), findsOneWidget);
      expect(find.text('A').hitTestable(), findsNothing);
    });

    testWidgets('sits at the start edge in RTL', (tester) async {
      await pumpMinimizable(
        tester,
        minimized: true,
        direction: TextDirection.rtl,
      );
      await tester.pumpAndSettle();
      expect(glass(tester).width, _metrics.thickness);
      expect(glass(tester).right, bar(tester).right);
    });

    testWidgets('a tap on the pill asks to expand and selects nothing', (
      tester,
    ) async {
      final log = await pumpMinimizable(tester, minimized: true);
      await tester.pumpAndSettle();
      await tester.tap(find.text('min2'));
      await tester.pumpAndSettle();
      expect(log.calls, ['expand']);
      expect(log.selections, isEmpty);
    });

    testWidgets('a touch beside the pill reaches the page under the bar', (
      tester,
    ) async {
      final log = await pumpMinimizable(tester, minimized: true);
      await tester.pumpAndSettle();
      await tester.tapAt(bar(tester).centerRight - const Offset(20, 0));
      expect(log.calls, ['page']);
    });

    testWidgets('springs back to the full bar', (tester) async {
      await pumpMinimizable(tester, minimized: true);
      await tester.pumpAndSettle();
      await pumpMinimizable(tester, minimized: false);
      await _advance(tester, 60);
      expect(glass(tester).width, inExclusiveRange(_metrics.thickness, 408));
      await tester.pumpAndSettle();
      expect(glass(tester).width, 408);
      expect(find.text('A').hitTestable(), findsOneWidget);
    });

    testWidgets('reduced motion minimizes at once', (tester) async {
      await pumpMinimizable(tester, minimized: false, reduceMotion: true);
      await pumpMinimizable(tester, minimized: true, reduceMotion: true);
      await tester.pump();
      expect(glass(tester).width, _metrics.thickness);
    });

    testWidgets('stays a full bar for a screen reader', (tester) async {
      await pumpMinimizable(tester, minimized: true, screenReader: true);
      await tester.pumpAndSettle();
      expect(glass(tester).width, 408);
    });

    testWidgets('once grown back, a tap where the pill was reaches the bar', (
      tester,
    ) async {
      final log = await pumpMinimizable(tester, minimized: true);
      await tester.pumpAndSettle();
      await pumpMinimizable(tester, minimized: false, record: log);
      await tester.pumpAndSettle();
      // Where the pill's tab sat, at the start edge.
      await tester.tapAt(glass(tester).centerLeft + const Offset(24, 0));
      await tester.pumpAndSettle();
      expect(log.selections, [0]);
    });
  });
}
