import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_shader/src/guard_frames.dart';

FrameTiming _frame(int number, int vsyncMicros, {int rasterMicros = 2000}) =>
    FrameTiming(
      vsyncStart: vsyncMicros,
      buildStart: vsyncMicros,
      buildFinish: vsyncMicros + 500,
      rasterStart: vsyncMicros + 500,
      rasterFinish: vsyncMicros + 500 + rasterMicros,
      rasterFinishWallTime: vsyncMicros + 500 + rasterMicros,
      frameNumber: number,
    );

void main() {
  test('a gap is measured only after a frame that asked for the next', () {
    final frames = guardFramesFrom(
      [
        _frame(1, 0),
        _frame(2, 16667),
        // Frame 2 asked for nothing: the app sat idle until a tap.
        _frame(3, 616667),
        _frame(4, 650000),
      ],
      askedForNext: {1, 3},
    );
    expect(frames.map((f) => f.gap?.inMicroseconds), [
      null,
      16667,
      null,
      33333,
    ]);
    expect(frames.first.raster, const Duration(microseconds: 2000));
  });

  test('links to the last frame of the previous batch', () {
    final frames = guardFramesFrom(
      [_frame(5, 66667)],
      previous: _frame(4, 50000),
      askedForNext: {4},
    );
    expect(frames.single.gap, const Duration(microseconds: 16667));
  });

  test('frames that are not consecutive have no gap', () {
    final frames = guardFramesFrom(
      [_frame(1, 0), _frame(3, 33333)],
      askedForNext: {1, 2},
    );
    expect(frames.last.gap, isNull);
  });
}
