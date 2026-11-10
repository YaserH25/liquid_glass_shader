import 'dart:developer';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';

import 'active_glass.dart';
import 'glass_guard.dart';
import 'glass_look.dart';
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
/// ([guard]), so slower devices stay smooth instead of janky. Only frames
/// in which glass drew a backdrop count: a page covered by another does
/// not lose its glass for the other page's jank.
///
/// Glass works without a scope: regular style, and [GlassThemeData.light] or
/// [GlassThemeData.dark] by the app's brightness (a Material or Cupertino
/// theme's, else the platform's).
class GlassScope extends StatefulWidget {
  /// Glass settings for [child].
  const GlassScope({
    super.key,
    this.style = GlassStyle.regular,
    this.tinting,
    this.theme,
    this.guard = const GlassGuard(),
    this.initialCap = GlassQuality.refraction,
    this.onCapChanged,
    required this.child,
  });

  /// How glass below looks unless a surface forces a style.
  final GlassStyle style;

  /// A look between the theme's three instead of [style], as the Liquid
  /// Glass slider of iOS 27 sets it: 0 is clear, 0.5 regular and 1 frosted
  /// ([GlassThemeData.lookAt]). None follows [style].
  final double? tinting;

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

  /// The glass style here (regular when there is no scope).
  static GlassStyle styleOf(BuildContext context) =>
      _of(context)?.style ?? GlassStyle.regular;

  /// The look of glass here that forces none: the theme's look at the
  /// scope's [tinting], or else for its [style].
  static GlassLook lookOf(BuildContext context) {
    final theme = themeOf(context);
    final tinting = _of(context)?.tinting;
    return tinting == null
        ? theme.look(styleOf(context))
        : theme.lookAt(tinting);
  }

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
  /// frames drawn with glass on screen, and the last frame timed, so gaps
  /// can be judged across batches.
  final Set<int> _askedForNext = {};
  final Set<int> _glassFrames = {};
  FrameTiming? _lastTimed;

  /// The last frame drawn before the tier last stepped down. The engine
  /// reports timings in batches up to a second late, so the first batch
  /// after a step down still holds frames drawn at the tier before; they
  /// say nothing about the new one.
  int _steppedDownAfter = -1;

  /// Whether frame timings are being watched: only while the guard may
  /// still step down.
  bool _watching = false;
  bool _noteScheduled = false;

  /// The current ceiling on glass quality.
  GlassQuality get cap => _cap;

  /// Whether the guard is watching frame timings: only while it is on and
  /// glass can still step down.
  @visibleForTesting
  bool get watchesFrames => _watching;

  @override
  void initState() {
    super.initState();
    _watchWhileNeeded();
  }

  @override
  void didUpdateWidget(GlassScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.guard != widget.guard) _watchWhileNeeded();
  }

  @override
  void dispose() {
    if (_watching) {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    }
    super.dispose();
  }

  /// Watches frame timings while the guard is on and glass can still step
  /// down; a disabled guard, or glass that is already solid, costs nothing
  /// per frame.
  void _watchWhileNeeded() {
    final needed = widget.guard.enabled && _cap != GlassQuality.solid;
    if (needed == _watching) return;
    _watching = needed;
    if (needed) {
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
      _scheduleNote();
    } else {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
      _resetWindows();
      _askedForNext.clear();
      _glassFrames.clear();
      _lastTimed = null;
    }
  }

  void _scheduleNote() {
    if (_noteScheduled) return;
    _noteScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback(_noteFrame);
  }

  /// After every frame, notes whether the next one is already wanted (a
  /// scroll or an animation running), and whether glass drew a backdrop in
  /// it. Post-frame callbacks do not cause frames, so an idle app costs
  /// nothing.
  void _noteFrame(Duration _) {
    _noteScheduled = false;
    if (!mounted || !_watching) return;
    final frame = PlatformDispatcher.instance.frameData.frameNumber;
    if (SchedulerBinding.instance.hasScheduledFrame) _askedForNext.add(frame);
    if (glassOnScreen) _glassFrames.add(frame);
    _scheduleNote();
  }

  /// The display's frame rate right now (it can change with display modes).
  double get _refreshRate {
    final rate = mounted ? View.maybeOf(context)?.display.refreshRate : null;
    return rate != null && rate > 0 ? rate : 60;
  }

  void _onTimings(List<FrameTiming> timings) {
    if (timings.isEmpty) return;
    final runs = guardRunsFrom(
      [
        for (final timing in timings)
          if (timing.frameNumber > _steppedDownAfter) timing,
      ],
      previous: _lastTimed,
      askedForNext: _askedForNext,
      glassFrames: _glassFrames,
    );
    final last = timings.last.frameNumber;
    _lastTimed = timings.last;
    _askedForNext.removeWhere((n) => n < last);
    _glassFrames.removeWhere((n) => n <= last);
    final cap = _cap;
    for (final run in runs) {
      recordFrames(run.frames, glassOnScreen: run.glass);
      // Every frame of this batch was drawn at the tier before.
      if (_cap != cap) break;
    }
  }

  void _resetWindows() {
    _window.clear();
    _windowTime = 0;
    _slowWindows = 0;
  }

  /// Judges frames in windows of [GlassGuard.window] and steps the tier
  /// down after two slow windows in a row, or after one severely slow
  /// window ([GlassGuard.severeShare]).
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
      _resetWindows();
      return;
    }
    final budget = 1e6 / _refreshRate;
    for (final frame in frames) {
      _window.add(frame);
      final length = (frame.gap ?? frame.raster).inMicroseconds;
      _windowTime += math.max(budget, length.toDouble());
      // The rest of these frames were drawn at the tier before.
      if (_windowTime >= guard.window.inMicroseconds && _closeWindow()) return;
    }
  }

  /// The tier glass actually draws at, which the guard steps down from.
  GlassQuality get _current => GlassScope._lower(GlassScope._best, _cap);

  /// Judges the window just filled, and steps down after two slow ones in a
  /// row, or one severely slow one; true when it stepped down.
  bool _closeWindow() {
    final guard = widget.guard;
    final share = _late(_window) / _window.length;
    _window.clear();
    _windowTime = 0;
    if (share > math.max(guard.severeShare, guard.lateShare)) {
      _slowWindows = 2;
    } else {
      _slowWindows = share > guard.lateShare ? _slowWindows + 1 : 0;
    }
    if (_slowWindows < 2) return false;

    _slowWindows = 0;
    _steppedDownAfter = PlatformDispatcher.instance.frameData.frameNumber;
    final next = GlassQuality.values[_current.index + 1];
    log('Glass frames too slow; stepping down to ${next.name}', name: 'glass');
    if (!mounted) return true;
    setState(() => _cap = next);
    _watchWhileNeeded();
    widget.onCapChanged?.call(next);
    return true;
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
      tinting: widget.tinting,
      theme: widget.theme,
      cap: _cap,
      child: widget.child,
    ),
  );
}

class _GlassScopeData extends InheritedWidget {
  const _GlassScopeData({
    required this.style,
    required this.tinting,
    required this.theme,
    required this.cap,
    required super.child,
  });

  final GlassStyle style;
  final double? tinting;
  final GlassThemeData? theme;
  final GlassQuality cap;

  @override
  bool updateShouldNotify(_GlassScopeData old) =>
      old.style != style ||
      old.tinting != tinting ||
      old.theme != theme ||
      old.cap != cap;
}
