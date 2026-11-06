import 'package:flutter/foundation.dart';

/// When glass steps down a quality tier to keep frames on time: after two
/// windows of [window] of drawing time in a row in which more than
/// [lateShare] of the frames were late while glass was on screen, or after
/// a single window in which more than [severeShare] were.
@immutable
class GlassGuard {
  /// A guard with the given window and shares.
  ///
  /// The defaults react within about two seconds on any phone, however few
  /// frames it manages, so a phone that stutters steps down before the
  /// stutter shows on every screen; one that misses most of its frames
  /// steps down within a second. A phone that keeps up misses almost no
  /// frames and keeps full refraction.
  const GlassGuard({
    this.window = const Duration(seconds: 1),
    this.lateShare = 0.1,
    this.severeShare = 0.5,
    this.enabled = true,
  });

  /// Drawing time per window.
  final Duration window;

  /// Share of late frames (0 to 1) above which a window counts as slow.
  final double lateShare;

  /// Share of late frames above which one slow window is enough to step
  /// down; never below [lateShare]. 1 or more always waits for two.
  final double severeShare;

  /// Off keeps the starting tier for the whole session.
  final bool enabled;

  @override
  bool operator ==(Object other) =>
      other is GlassGuard &&
      other.window == window &&
      other.lateShare == lateShare &&
      other.severeShare == severeShare &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(window, lateShare, severeShare, enabled);
}
