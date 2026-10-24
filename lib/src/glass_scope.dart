import 'dart:developer';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';

import 'active_glass.dart';
import 'glass_guard.dart';
import 'glass_quality.dart';
import 'glass_style.dart';
import 'glass_theme_data.dart';
import 'guard_frames.dart';
import 'liquid_glass_shader_loader.dart';

/// Gives every glass surface below it a [style], a [theme], and the quality
/// tier the device can afford.
///
/// The tier starts at the best the device supports (the shader with
/// Impeller, otherwise a blur; opaque under high contrast). While glass is
/// on screen, the scope watches frame timings and steps the tier down for
/// the rest of the session when frames keep missing the display's budget
/// ([guard]), so slower devices stay smooth instead of janky.
///
/// Glass works without a scope: clear style, and [GlassThemeData.light] or
/// [GlassThemeData.dark] by the app's brightness (a Material or Cupertino
/// theme's, else the platform's).
class GlassScope extends StatefulWidget {
  /// Glass settings for [child].
  const GlassScope({
    super.key,
    this.style = GlassStyle.clear,
    this.theme,
    this.guard = const GlassGuard(),
    this.initialCap = GlassQuality.refraction,
    this.onCapChanged,
    required this.child,
  });

  /// How glass below looks unless a surface forces a style.
  final GlassStyle style;

  /// Colours and looks; none follows the app's brightness.
  final GlassThemeData? theme;

  /// When to step down a quality tier.
  final GlassGuard guard;

  /// The ceiling glass starts at. An app that saved the tier the guard
  /// picked ([onCapChanged]) passes it here, so a slow device does not
  /// stutter again on every launch before the guard steps down. Read once,
  /// when the scope is created.
  final GlassQuality initialCap;

  /// Called with the new ceiling each time the guard steps down.
  final ValueChanged<GlassQuality>? onCapChanged;

  /// The subtree that uses this glass.
  final Widget child;

  static _GlassScopeData? _of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GlassScopeData>();

  /// The glass style here (clear when there is no scope).
  static GlassStyle styleOf(BuildContext context) =>
      _of(context)?.style ?? GlassStyle.clear;

  /// The glass theme here: the scope's, or the default for the app's
  /// brightness (a Material or Cupertino theme's, else the platform's).
  static GlassThemeData themeOf(BuildContext context) =>
      _of(context)?.theme ??
      // A Material Theme also provides a CupertinoTheme with its brightness,
      // so this covers MaterialApp, CupertinoApp and plain WidgetsApp.
      (CupertinoTheme.brightnessOf(context) == Brightness.dark
          ? GlassThemeData.dark()
          : GlassThemeData.light());

  /// The quality tier glass should draw at here. Depends on the shader, so
  /// callers listen to [LiquidGlassShader.program] to rebuild when it loads.
  static GlassQuality qualityOf(BuildContext context) {
    if (MediaQuery.highContrastOf(context)) return GlassQuality.solid;
    final cap = _of(context)?.cap ?? GlassQuality.refraction;
    return _lower(_best, cap);
  }

  /// The best tier this device supports.
  static GlassQuality get _best =>
      LiquidGlassShader.isReady ? GlassQuality.refraction : GlassQuality.blur;

  static GlassQuality _lower(GlassQuality a, GlassQuality b) =>
      a.index > b.index ? a : b;

  @override
  State<GlassScope> createState() => GlassScopeState();
}

/// The state of a [GlassScope]: holds the quality cap the guard has set.
class GlassScopeState extends State<GlassScope> {
  late GlassQuality _cap = widget.initialCap;
  final List<GuardFrame> _window = [];
  double _windowTime = 0;
  int _slowWindows = 0;

  /// Frames that had already asked for the next frame when they finished,
  /// and the last frame timed, so gaps can be judged across batches.
  final Set<int> _askedForNext = {};
  FrameTiming? _lastTimed;

  /// The current ceiling on glass quality.
  GlassQuality get cap => _cap;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    SchedulerBinding.instance.addPostFrameCallback(_noteFrame);
  }

  /// After every frame, notes whether the next one is already wanted (a
  /// scroll or an animation running). Post-frame callbacks do not cause
  /// frames, so an idle app costs nothing.
  void _noteFrame(Duration _) {
    if (!mounted) return;
    if (SchedulerBinding.instance.hasScheduledFrame) {
      _askedForNext.add(PlatformDispatcher.instance.frameData.frameNumber);
    }
    SchedulerBinding.instance.addPostFrameCallback(_noteFrame);
  }

  /// The display's frame rate right now (it can change with display modes).
  double get _refreshRate {
    final rate = mounted ? View.maybeOf(context)?.display.refreshRate : null;
    return rate != null && rate > 0 ? rate : 60;
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    super.dispose();
  }

  void _onTimings(List<FrameTiming> timings) {
    if (timings.isEmpty) return;
    final frames = guardFramesFrom(
      timings,
      previous: _lastTimed,
      askedForNext: _askedForNext,
    );
    _lastTimed = timings.last;
    _askedForNext.removeWhere((n) => n < timings.last.frameNumber);
    recordFrames(frames, glassOnScreen: activeGlassSurfaces > 0);
  }

  /// Judges frames in windows of [GlassGuard.window] and steps the tier
  /// down after two slow windows in a row.
  ///
  /// A window is a stretch of drawing time, not a count of frames: each
  /// frame counts its gap, or its raster time when it has no gap, and at
  /// least one frame budget. A phone that draws only a few frames a second
  /// would otherwise take minutes to fill a window of frames, and suffer
  /// the longest of all.
  ///
  /// A frame is late when its raster time misses the display's frame
  /// budget, or when it lands late: its gap is more than 1.5 times the
  /// window's usual gap. On iPhone the GPU's work does not show in raster
  /// time, so a GPU that cannot keep up shows only in the gaps. Measuring
  /// against the usual gap rather than the reported refresh rate keeps a
  /// display that runs slower than it reports (Low Power Mode) from looking
  /// slow; a usual gap over 2.5 frame budgets (a steady 30fps on 120Hz)
  /// makes every judged frame late.
  @visibleForTesting
  void recordFrames(
    Iterable<GuardFrame> frames, {
    required bool glassOnScreen,
  }) {
    final guard = widget.guard;
    if (!guard.enabled || !glassOnScreen || _current == GlassQuality.solid) {
      _window.clear();
      _windowTime = 0;
      _slowWindows = 0;
      return;
    }
    final budget = 1e6 / _refreshRate;
    for (final frame in frames) {
      if (_current == GlassQuality.solid) return;
      _window.add(frame);
      final length = (frame.gap ?? frame.raster).inMicroseconds;
      _windowTime += math.max(budget, length.toDouble());
      if (_windowTime >= guard.window.inMicroseconds) _closeWindow();
    }
  }

  /// The tier glass actually draws at, which the guard steps down from.
  GlassQuality get _current => GlassScope._lower(GlassScope._best, _cap);

  void _closeWindow() {
    final slow = _late(_window) / _window.length > widget.guard.lateShare;
    _window.clear();
    _windowTime = 0;
    _slowWindows = slow ? _slowWindows + 1 : 0;
    if (_slowWindows < 2) return;

    _slowWindows = 0;
    final next = GlassQuality.values[_current.index + 1];
    log('Glass frames too slow; stepping down to ${next.name}', name: 'glass');
    if (!mounted) return;
    setState(() => _cap = next);
    widget.onCapChanged?.call(next);
  }

  int _late(List<GuardFrame> frames) {
    final budget = 1e6 / _refreshRate;
    final gaps = [
      for (final frame in frames)
        if (frame.gap case final gap?) gap.inMicroseconds,
    ]..sort();
    final usual = gaps.isEmpty
        ? budget
        : math.max(budget, gaps[gaps.length ~/ 2].toDouble());
    final steadilySlow = usual > 2.5 * budget;
    return frames.where((frame) {
      if (frame.raster.inMicroseconds > budget) return true;
      final gap = frame.gap;
      if (gap == null) return false;
      return steadilySlow || gap.inMicroseconds > 1.5 * usual;
    }).length;
  }

  /// The backdrop that glass below shares when it opts in.
  final BackdropKey _backdropKey = BackdropKey();

  @override
  Widget build(BuildContext context) => BackdropGroup(
    backdropKey: _backdropKey,
    child: _GlassScopeData(
      style: widget.style,
      theme: widget.theme,
      cap: _cap,
      child: widget.child,
    ),
  );
}

class _GlassScopeData extends InheritedWidget {
  const _GlassScopeData({
    required this.style,
    required this.theme,
    required this.cap,
    required super.child,
  });

  final GlassStyle style;
  final GlassThemeData? theme;
  final GlassQuality cap;

  @override
  bool updateShouldNotify(_GlassScopeData old) =>
      old.style != style || old.theme != theme || old.cap != cap;
}
