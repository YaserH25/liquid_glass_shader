import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../liquid_tab_bar_style.dart';
import 'springs.dart';

/// How a tab bar's lens moves: where it is along the row, how far it is
/// lifted, and how drawn out it is (the jelly).
///
/// Positions are in tab slots counted from the physical left: 0 is the
/// centre of the first slot.
class LensMotion {
  /// Motion ticking with [vsync].
  LensMotion({required TickerProvider vsync})
    : position = AnimationController.unbounded(vsync: vsync),
      lift = AnimationController.unbounded(vsync: vsync) {
    _catchUp = vsync.createTicker(_onCatchUpTick);
    _jelly = vsync.createTicker(_onJellyTick);
    position.addListener(_wakeJelly);
  }

  /// The centre of the lens.
  final AnimationController position;

  /// 0 at rest, 1 lifted under a finger (springs past both a little).
  final AnimationController lift;

  /// How drawn out the lens is along its path: 0 is round, negative while
  /// it wobbles back.
  ValueListenable<double> get stretch => _stretch;
  final ValueNotifier<double> _stretch = ValueNotifier(0);

  /// The springs and the feel; the owner keeps it current.
  LiquidTabBarStyle style = LiquidTabBarStyle.standard;

  /// Moves the lens at once and keeps it flat; the owner keeps it current.
  bool reduceMotion = false;

  /// Closes the gap between the lens and the finger after touch-down, by
  /// frame time.
  ///
  /// A spring restarted on every move never advances on a real touchscreen:
  /// moves arrive before every frame, so each frame is the first tick of a
  /// new spring and the lens freezes until the finger pauses. Instead the
  /// lens sits at the finger plus [_gap], and only the gap animates, so the
  /// lens moves with the finger from the first frame while the jump closes.
  late final Ticker _catchUp;
  Duration _lastTick = Duration.zero;

  /// Where the finger is, in slots (with the rubber band past the ends), and
  /// how far the lens still is from it.
  double _finger = 0;
  double _gap = 0;

  /// The jelly, driven each frame by how fast the lens actually moves, so it
  /// stretches with a swipe or a slide and rounds out with a wobble when it
  /// stops.
  late final Ticker _jelly;
  double _stretchVelocity = 0;
  double _speed = 0;
  double _lastPosition = 0;
  Duration _jellyLast = Duration.zero;

  static const double _jellyStep = 1 / 240;

  /// Puts the lens on [slot] at once.
  void jumpTo(double slot) {
    position.stop();
    position.value = slot;
  }

  /// Springs the lens onto [slot].
  void settleOn(double slot) =>
      springTo(position, style.settle, slot, reduceMotion: reduceMotion);

  /// Lifts the lens under a finger, or drops it back into the bar.
  void setLifted(bool lifted) {
    if (reduceMotion) {
      lift.value = 0;
      return;
    }
    springTo(
      lift,
      lifted ? style.lift : style.drop,
      lifted ? 1 : 0,
      reduceMotion: false,
    );
  }

  /// Follows a finger at slot [raw], resisting past the first slot and
  /// [last]. Reduced motion puts the lens on [nearest] instead. [jump]
  /// starts a glide from wherever the lens is, as at touch-down.
  void follow(
    double raw, {
    required int nearest,
    required double last,
    bool jump = false,
  }) {
    _finger = _rubberBand(raw, last);
    if (reduceMotion) {
      position.value = nearest.toDouble();
      return;
    }
    if (jump) {
      position.stop();
      _gap = position.value - _finger;
      _lastTick = Duration.zero;
      if (!_catchUp.isActive) _catchUp.start();
    }
    // Follow the finger in this frame, plus whatever gap is left.
    position.value = _finger + _gap;
  }

  /// Stops following the finger and drops the lens.
  void release() {
    _catchUp.stop();
    _gap = 0;
    setLifted(false);
  }

  void _onCatchUpTick(Duration elapsed) {
    final seconds = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    // Exponential decay: frame-rate independent, never overshoots.
    _gap *= math.exp(-seconds * style.catchUp);
    if (_gap.abs() < 0.005) {
      _gap = 0;
      _catchUp.stop();
    }
    position.value = _finger + _gap;
  }

  /// [raw] slot position, resisting more and more past the first and last
  /// slot so the lens never travels more than [LiquidTabBarStyle.rubberBand]
  /// beyond them.
  double _rubberBand(double raw, double last) {
    final over = raw < 0 ? -raw : raw - last;
    if (over <= 0) return raw;
    final reach = style.rubberBand;
    final pulled = reach * (1 - 1 / (over / reach + 1));
    return raw < 0 ? -pulled : last + pulled;
  }

  void _wakeJelly() {
    if (_jelly.isActive || reduceMotion) return;
    _jellyLast = Duration.zero;
    _lastPosition = position.value;
    _jelly.start();
  }

  void _onJellyTick(Duration elapsed) {
    final seconds = (elapsed - _jellyLast).inMicroseconds / 1e6;
    _jellyLast = elapsed;
    if (seconds <= 0) return;

    final measured = (position.value - _lastPosition) / seconds;
    _lastPosition = position.value;
    _speed +=
        (measured - _speed) * (1 - math.exp(-seconds * style.speedSmoothing));
    final target = math.min(
      _speed.abs() * style.stretchPerSpeed,
      style.maxStretch,
    );

    // The loose spring, in small fixed steps so it stays stable at any frame
    // rate.
    final spring = style.jelly;
    var stretch = _stretch.value;
    var velocity = _stretchVelocity;
    for (var left = seconds; left > 0; left -= _jellyStep) {
      final step = math.min(left, _jellyStep);
      final force =
          spring.stiffness * (target - stretch) - spring.damping * velocity;
      velocity += force / spring.mass * step;
      stretch += velocity * step;
    }
    _stretchVelocity = velocity;

    final still =
        _speed.abs() < 0.01 && stretch.abs() < 0.001 && velocity.abs() < 0.01;
    // A resting finger stops it too: the next move sets the position, which
    // wakes it.
    if (still && !position.isAnimating) {
      _speed = 0;
      _stretchVelocity = 0;
      _stretch.value = 0;
      _jelly.stop();
    } else {
      _stretch.value = stretch;
    }
  }

  /// Stops every ticker and releases the controllers.
  void dispose() {
    position.removeListener(_wakeJelly);
    _jelly.dispose();
    _stretch.dispose();
    _catchUp.dispose();
    position.dispose();
    lift.dispose();
  }
}
