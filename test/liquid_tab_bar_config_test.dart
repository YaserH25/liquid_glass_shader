import 'package:flutter/painting.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_shader/liquid_glass_shader.dart';

void main() {
  test('metrics compare by value and copy with changes', () {
    const metrics = LiquidTabBarMetrics(thickness: 50, tabExtent: 80);
    expect(metrics, const LiquidTabBarMetrics(thickness: 50, tabExtent: 80));
    expect(metrics, isNot(LiquidTabBarMetrics.stacked));

    final copy = metrics.copyWith(lensGap: const EdgeInsets.all(2));
    expect(copy.thickness, 50);
    expect(copy.tabExtent, 80);
    expect(copy.lensGap, const EdgeInsets.all(2));
    expect(copy.hashCode, isNot(metrics.hashCode));
  });

  test('presets carry the measured iOS sizes', () {
    expect(LiquidTabBarMetrics.stacked.thickness, 62);
    expect(LiquidTabBarMetrics.inline.thickness, 46);
    expect(LiquidTabBarMetrics.compactInline.thickness, 44);
  });

  test('motion compares its springs by value', () {
    expect(LiquidTabBarMotion(), LiquidTabBarMotion.standard);
    expect(LiquidTabBarMotion().hashCode, LiquidTabBarMotion.standard.hashCode);

    final bouncier = LiquidTabBarMotion.standard.copyWith(
      settle: SpringDescription.withDampingRatio(
        mass: 1,
        stiffness: 700,
        ratio: 0.5,
      ),
    );
    expect(bouncier, isNot(LiquidTabBarMotion.standard));
    expect(bouncier.catchUp, LiquidTabBarMotion.standard.catchUp);
  });

  test('lens compares by value and copies with changes', () {
    final lens = LiquidTabBarLens.standard.copyWith(magnification: 1.3);
    expect(lens, const LiquidTabBarLens(magnification: 1.3));
    expect(lens, isNot(LiquidTabBarLens.standard));
    expect(lens.bend, LiquidTabBarLens.standard.bend);
  });
}
