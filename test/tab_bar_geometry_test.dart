import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_shader/liquid_glass_shader.dart';
import 'package:liquid_glass_shader/src/tab_bar/tab_bar_geometry.dart';

void main() {
  const row = Size(400, 50);
  const ltr = TabBarGeometry(count: 4, axis: Axis.horizontal, rtl: false);
  const rtl = TabBarGeometry(count: 4, axis: Axis.horizontal, rtl: true);
  const optics = LiquidTabBarLens(liftedExtent: 1.2, liftedThickness: 1.3);

  test('maps tabs to slots from the physical left', () {
    expect([for (var i = 0; i < 4; i++) ltr.flip(i)], [0, 1, 2, 3]);
    expect([for (var i = 0; i < 4; i++) rtl.flip(i)], [3, 2, 1, 0]);
  });

  test('finds the slot under a point, 0 at the first slot centre', () {
    expect(ltr.slotAt(const Offset(50, 25), row), 0);
    expect(ltr.slotAt(const Offset(250, 25), row), 2);
    expect(ltr.slotAt(const Offset(100, 25), row), 0.5);
  });

  test('the resting lens fills its slot', () {
    final lens = ltr.lensRect(row, 2, lift: 0, stretch: 0, lens: optics);
    expect(lens, const Rect.fromLTWH(200, 0, 100, 50));
  });

  test('the lens grows as it lifts and draws out as it moves', () {
    final lifted = ltr.lensRect(row, 0, lift: 1, stretch: 0, lens: optics);
    expect(lifted.center, const Offset(50, 25));
    expect(lifted.width, closeTo(120, 1e-9));
    expect(lifted.height, closeTo(65, 1e-9));

    final moving = ltr.lensRect(row, 0, lift: 0, stretch: 0.2, lens: optics);
    expect(moving.width, closeTo(120, 1e-9));
    expect(moving.height, lessThan(50));
  });

  group('vertical', () {
    const column = Size(50, 400);
    const down = TabBarGeometry(count: 4, axis: Axis.vertical, rtl: true);

    test('runs from the top in either text direction', () {
      expect([for (var i = 0; i < 4; i++) down.flip(i)], [0, 1, 2, 3]);
    });

    test('finds the slot under a point down the column', () {
      expect(down.slotAt(const Offset(25, 50), column), 0);
      expect(down.slotAt(const Offset(25, 250), column), 2);
    });

    test('the lens fills its slot, grows and draws out down the column', () {
      expect(
        down.lensRect(column, 1, lift: 0, stretch: 0, lens: optics),
        const Rect.fromLTWH(0, 100, 50, 100),
      );
      final lifted = down.lensRect(
        column,
        0,
        lift: 1,
        stretch: 0,
        lens: optics,
      );
      expect(lifted.height, closeTo(120, 1e-9));
      expect(lifted.width, closeTo(65, 1e-9));
      final moving = down.lensRect(
        column,
        0,
        lift: 0,
        stretch: 0.2,
        lens: optics,
      );
      expect(moving.height, closeTo(120, 1e-9));
      expect(moving.width, lessThan(50));
    });

    test('a lens gap applies on the physical sides', () {
      final lens = down.lensRect(
        column,
        0,
        lift: 0,
        stretch: 0,
        lens: optics,
        gap: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
      );
      expect(lens, const Rect.fromLTWH(5, 10, 40, 80));
    });
  });
}
