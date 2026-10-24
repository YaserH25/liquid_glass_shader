import 'package:flutter/foundation.dart';

/// When glass steps down a quality tier to keep frames on time: after two
/// windows of [window] of drawing time in a row in which more than
/// [lateShare] of the frames were late while glass was on screen.
@immutable
class GlassGuard {
  /// A guard with the given window and share.
  ///
  /// The defaults react within about two seconds on any phone, however few
  /// frames it manages, so a phone that stutters steps down before the
  /// stutter shows on every screen. A phone that keeps up misses almost no
  /// frames and keeps full refraction.
  const GlassGuard({
    this.window = const Duration(seconds: 1),
    this.lateShare = 0.1,
    this.enabled = true,
  });

  /// Drawing time per window.
  final Duration window;

  /// Share of late frames (0 to 1) above which a window counts as slow.
  final double lateShare;

  /// Off keeps the starting tier for the whole session.
  final bool enabled;

  @override
  bool operator ==(Object other) =>
      other is GlassGuard &&
      other.window == window &&
      other.lateShare == lateShare &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(window, lateShare, enabled);
}
