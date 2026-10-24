import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';

/// How a `LiquidTabBar`'s lens moves. The defaults match the iOS 26 tab
/// bar, measured frame by frame on the iPhone 17 simulator.
@immutable
class LiquidTabBarMotion {
  /// Motion; every value has a default.
  LiquidTabBarMotion({
    SpringDescription? settle,
    SpringDescription? lift,
    SpringDescription? drop,
    SpringDescription? jelly,
    SpringDescription? minimize,
    this.catchUp = 35,
    this.pressedScale = 1.04,
    this.stretchPerSpeed = 0.018,
    this.maxStretch = 0.35,
    this.speedSmoothing = 30,
    this.rubberBand = 0.06,
  }) : settle = settle ?? _spring(700, 0.8),
       lift = lift ?? _spring(600, 0.7),
       drop = drop ?? _spring(900, 1),
       jelly = jelly ?? _spring(400, 0.5),
       minimize = minimize ?? _spring(500, 0.9);

  static SpringDescription _spring(double stiffness, double ratio) =>
      SpringDescription.withDampingRatio(
        mass: 1,
        stiffness: stiffness,
        ratio: ratio,
      );

  /// The default motion.
  static final LiquidTabBarMotion standard = LiquidTabBarMotion();

  /// The lens settling on a tab after a release or a tab change: quick
  /// (about 0.25s) with a slight overshoot.
  final SpringDescription settle;

  /// The lens lifting under a finger, with a little gel-like overshoot.
  final SpringDescription lift;

  /// The lens dropping back into the bar on release: critically damped by
  /// default, so it never dips past rest and rises again.
  final SpringDescription drop;

  /// The loose spring that draws the lens out with its speed and wobbles it
  /// back round when it stops, like a drop of water.
  final SpringDescription jelly;

  /// The bar shrinking into its pill, and growing back: quick, barely
  /// overshooting.
  final SpringDescription minimize;

  /// How fast the gap between the lens and the finger closes after
  /// touch-down, per second (exponential). The lens moves with the finger
  /// meanwhile, so it never trails.
  final double catchUp;

  /// How much the whole bar swells while a finger is on it.
  final double pressedScale;

  /// How far the lens draws out per tab per second of speed.
  final double stretchPerSpeed;

  /// The most the lens draws out (a fraction of its length).
  final double maxStretch;

  /// How quickly the measured lens speed follows the real one, per second
  /// (smooths out uneven touch events).
  final double speedSmoothing;

  /// How far, in tabs, the lens can be pulled past the first or last tab.
  final double rubberBand;

  /// A copy with the given values replaced.
  LiquidTabBarMotion copyWith({
    SpringDescription? settle,
    SpringDescription? lift,
    SpringDescription? drop,
    SpringDescription? jelly,
    SpringDescription? minimize,
    double? catchUp,
    double? pressedScale,
    double? stretchPerSpeed,
    double? maxStretch,
    double? speedSmoothing,
    double? rubberBand,
  }) => LiquidTabBarMotion(
    settle: settle ?? this.settle,
    lift: lift ?? this.lift,
    drop: drop ?? this.drop,
    jelly: jelly ?? this.jelly,
    minimize: minimize ?? this.minimize,
    catchUp: catchUp ?? this.catchUp,
    pressedScale: pressedScale ?? this.pressedScale,
    stretchPerSpeed: stretchPerSpeed ?? this.stretchPerSpeed,
    maxStretch: maxStretch ?? this.maxStretch,
    speedSmoothing: speedSmoothing ?? this.speedSmoothing,
    rubberBand: rubberBand ?? this.rubberBand,
  );

  // SpringDescription has no equality of its own.
  static bool _same(SpringDescription a, SpringDescription b) =>
      a.mass == b.mass && a.stiffness == b.stiffness && a.damping == b.damping;

  static int _hash(SpringDescription s) =>
      Object.hash(s.mass, s.stiffness, s.damping);

  @override
  bool operator ==(Object other) =>
      other is LiquidTabBarMotion &&
      _same(other.settle, settle) &&
      _same(other.lift, lift) &&
      _same(other.drop, drop) &&
      _same(other.jelly, jelly) &&
      _same(other.minimize, minimize) &&
      other.catchUp == catchUp &&
      other.pressedScale == pressedScale &&
      other.stretchPerSpeed == stretchPerSpeed &&
      other.maxStretch == maxStretch &&
      other.speedSmoothing == speedSmoothing &&
      other.rubberBand == rubberBand;

  @override
  int get hashCode => Object.hash(
    _hash(settle),
    _hash(lift),
    _hash(drop),
    _hash(jelly),
    _hash(minimize),
    catchUp,
    pressedScale,
    stretchPerSpeed,
    maxStretch,
    speedSmoothing,
    rubberBand,
  );
}
