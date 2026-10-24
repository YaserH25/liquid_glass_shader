import 'package:flutter/physics.dart';

/// Motion and optics of a `LiquidTabBar`'s lens. The defaults match the
/// iOS 26 tab bar, measured frame by frame on the iPhone 17 simulator.
class LiquidTabBarStyle {
  /// A style; every value has a default.
  LiquidTabBarStyle({
    SpringDescription? settle,
    SpringDescription? lift,
    SpringDescription? drop,
    SpringDescription? jelly,
    this.catchUp = 35,
    this.liftedWidth = 1.18,
    this.liftedHeight = 1.3,
    this.magnification = 1.17,
    this.pressedScale = 1.04,
    this.stretchPerSpeed = 0.018,
    this.maxStretch = 0.35,
    this.speedSmoothing = 30,
    this.rubberBand = 0.06,
    this.lensBand = 22,
    this.lensBend = 18,
    this.lensDispersion = 0.5,
    this.lensSpecular = 0.55,
  }) : settle =
           settle ??
           SpringDescription.withDampingRatio(
             mass: 1,
             stiffness: 700,
             ratio: 0.8,
           ),
       lift =
           lift ??
           SpringDescription.withDampingRatio(
             mass: 1,
             stiffness: 600,
             ratio: 0.7,
           ),
       drop =
           drop ??
           SpringDescription.withDampingRatio(
             mass: 1,
             stiffness: 900,
             ratio: 1,
           ),
       jelly =
           jelly ??
           SpringDescription.withDampingRatio(
             mass: 1,
             stiffness: 400,
             ratio: 0.5,
           );

  /// The default style.
  static final LiquidTabBarStyle standard = LiquidTabBarStyle();

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

  /// How fast the gap between the lens and the finger closes after
  /// touch-down, per second (exponential). The lens moves with the finger
  /// meanwhile, so it never trails.
  final double catchUp;

  /// The lifted lens's width against the resting one.
  final double liftedWidth;

  /// The lifted lens's height against the resting one, so it stands out
  /// over the bar.
  final double liftedHeight;

  /// How much the lifted lens magnifies the tabs under it.
  final double magnification;

  /// How much the whole bar swells while a finger is on it.
  final double pressedScale;

  /// How far the lens draws out per tab per second of speed.
  final double stretchPerSpeed;

  /// The most the lens draws out (a fraction of its width).
  final double maxStretch;

  /// How quickly the measured lens speed follows the real one, per second
  /// (smooths out uneven touch events).
  final double speedSmoothing;

  /// How far, in tabs, the lens can be pulled past the first or last tab.
  final double rubberBand;

  /// How far in from the rim the lifted lens curves, in logical pixels.
  final double lensBand;

  /// How far the lifted lens bends what is under it at the rim.
  final double lensBend;

  /// Colour split at the lifted lens's rim, as a fraction of [lensBend].
  final double lensDispersion;

  /// Light caught along the top of the lifted lens's rim (0 to 1).
  final double lensSpecular;
}
