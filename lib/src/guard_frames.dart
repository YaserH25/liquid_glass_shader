import 'dart:ui';

/// A frame as the quality guard judges it: its raster time, and how long
/// after the frame before it it began, when that can be judged.
typedef GuardFrame = ({Duration raster, Duration? gap});

/// Pairs each of [timings] with its raster time and its gap from the frame
/// before it ([previous] for the first one).
///
/// The gap shows work the raster time misses, such as a GPU that cannot keep
/// up. It is only measured when the frame before had already asked for this
/// one ([askedForNext] holds its frame number). Otherwise the app was idle
/// in between, and the gap says nothing about speed.
List<GuardFrame> guardFramesFrom(
  List<FrameTiming> timings, {
  FrameTiming? previous,
  required Set<int> askedForNext,
}) {
  final frames = <GuardFrame>[];
  for (final timing in timings) {
    final before = previous;
    final judged =
        before != null &&
        timing.frameNumber == before.frameNumber + 1 &&
        askedForNext.contains(before.frameNumber);
    frames.add((
      raster: timing.rasterDuration,
      gap: judged
          ? Duration(
              microseconds:
                  timing.timestampInMicroseconds(FramePhase.vsyncStart) -
                  before.timestampInMicroseconds(FramePhase.vsyncStart),
            )
          : null,
    ));
    previous = timing;
  }
  return frames;
}
