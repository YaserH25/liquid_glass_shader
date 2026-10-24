import 'dart:ui';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_shader/src/tab_bar/separating_fold.dart';

void main() {
  // A bar along the bottom of an 800-wide screen, 62 tall.
  const bar = Rect.fromLTRB(100, 500, 700, 562);

  DisplayFeature hinge(Rect bounds) => DisplayFeature(
    bounds: bounds,
    type: DisplayFeatureType.hinge,
    state: DisplayFeatureState.unknown,
  );
  DisplayFeature fold(double x, DisplayFeatureState state) => DisplayFeature(
    bounds: Rect.fromLTWH(x, 0, 0, 600),
    type: DisplayFeatureType.fold,
    state: state,
  );

  Rect? clear(
    List<DisplayFeature> features, {
    Rect of = bar,
    Axis axis = Axis.horizontal,
    double toward = 0,
    bool rtl = false,
  }) => clearOfFolds(of, features, axis: axis, toward: toward, rtl: rtl);

  test('a hinge across the bar leaves the side the alignment points to', () {
    final features = [hinge(const Rect.fromLTRB(380, 0, 420, 600))];
    expect(
      clear(features, toward: -1),
      const Rect.fromLTRB(100, 500, 380, 562),
    );
    expect(clear(features, toward: 1), const Rect.fromLTRB(420, 500, 700, 562));
  });

  test('a centred bar takes the larger side, the start side when even', () {
    expect(
      clear([hinge(const Rect.fromLTRB(300, 0, 320, 600))]),
      const Rect.fromLTRB(320, 500, 700, 562),
    );
    final even = [hinge(const Rect.fromLTRB(390, 0, 410, 600))];
    expect(clear(even), const Rect.fromLTRB(100, 500, 390, 562));
    expect(clear(even, rtl: true), const Rect.fromLTRB(410, 500, 700, 562));
  });

  test('a fold separates only while half open', () {
    expect(clear([fold(400, DisplayFeatureState.postureFlat)]), isNull);
    expect(
      clear([fold(400, DisplayFeatureState.postureHalfOpened)]),
      const Rect.fromLTRB(100, 500, 400, 562),
    );
  });

  test('cutouts, and features beside or along the bar, are left alone', () {
    final cutout = DisplayFeature(
      bounds: const Rect.fromLTRB(380, 500, 420, 530),
      type: DisplayFeatureType.cutout,
      state: DisplayFeatureState.unknown,
    );
    expect(clear([cutout]), isNull);
    // Up the screen, clear of the bar.
    expect(clear([hinge(const Rect.fromLTRB(380, 0, 420, 300))]), isNull);
    // Along the bar, not across it: nothing to step around.
    expect(clear([hinge(const Rect.fromLTRB(0, 520, 800, 540))]), isNull);
  });

  test('a fold across a vertical bar leaves its top or bottom part', () {
    const column = Rect.fromLTRB(700, 100, 748, 600);
    final features = [hinge(const Rect.fromLTRB(0, 290, 800, 310))];
    expect(
      clear(features, of: column, axis: Axis.vertical, toward: -1),
      const Rect.fromLTRB(700, 100, 748, 290),
    );
    expect(
      clear(features, of: column, axis: Axis.vertical, toward: 1),
      const Rect.fromLTRB(700, 310, 748, 600),
    );
  });
}
