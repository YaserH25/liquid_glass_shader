import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

/// Springs [controller] to [target] from where it is, keeping its velocity,
/// or jumps there at once with [reduceMotion].
void springTo(
  AnimationController controller,
  SpringDescription spring,
  double target, {
  required bool reduceMotion,
}) {
  if (reduceMotion) {
    controller.value = target;
    return;
  }
  controller
      .animateWith(
        SpringSimulation(spring, controller.value, target, controller.velocity),
      )
      // Land exactly on the target; the spring stops within a tolerance.
      .then((_) => controller.value = target);
}
