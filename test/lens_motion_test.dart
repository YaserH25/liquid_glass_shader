import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_shader/liquid_glass_shader.dart';
import 'package:liquid_glass_shader/src/tab_bar/lens_motion.dart';

void main() {
  late LensMotion motion;
  final style = LiquidTabBarStyle.standard;

  setUp(() => motion = LensMotion(vsync: const TestVSync()));
  tearDown(() => motion.dispose());

  testWidgets('settles exactly on a slot', (tester) async {
    motion.settleOn(2);
    await tester.pumpAndSettle();
    expect(motion.position.value, 2);
  });

  testWidgets('never travels more than the rubber band past the ends', (
    tester,
  ) async {
    for (final raw in [3.5, 5.0, 40.0]) {
      motion.follow(raw, nearest: 3, last: 3);
      expect(motion.position.value, greaterThan(3));
      expect(motion.position.value, lessThan(3 + style.rubberBand));
    }
    motion.follow(-40, nearest: 0, last: 3);
    expect(motion.position.value, greaterThan(-style.rubberBand));
    await tester.pumpAndSettle();
  });

  testWidgets('glides from where it was to the finger after touch-down', (
    tester,
  ) async {
    motion.follow(2, nearest: 2, last: 3, jump: true);
    // Still where it was in the first frame, then catches up.
    expect(motion.position.value, 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(motion.position.value, inExclusiveRange(0, 2));
    await tester.pump(const Duration(milliseconds: 500));
    expect(motion.position.value, 2);
    await tester.pumpAndSettle();
  });

  testWidgets('draws out while it moves and rounds out after', (tester) async {
    motion.settleOn(3);
    var widest = 0.0;
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 8));
      if (motion.stretch.value > widest) widest = motion.stretch.value;
    }
    expect(widest, greaterThan(0.05));
    await tester.pumpAndSettle();
    expect(motion.stretch.value, 0);
  });

  testWidgets('reduced motion puts the lens on the nearest slot, flat', (
    tester,
  ) async {
    motion.reduceMotion = true;
    motion.follow(1.4, nearest: 1, last: 3, jump: true);
    expect(motion.position.value, 1);
    motion.settleOn(3);
    expect(motion.position.value, 3);
    expect(tester.binding.transientCallbackCount, 0);
  });
}
