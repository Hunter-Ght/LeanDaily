import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

import '../theme/tokens.dart';

double project(double velocity, [double rate = Motion.projectRate]) =>
    velocity / Duration.millisecondsPerSecond * rate / (1 - rate);
double rubberband(double over, double dimension) =>
    over.abs() *
    dimension *
    Motion.rubberConstant /
    (dimension + Motion.rubberConstant * over.abs());
Future<bool> springTo(
  AnimationController controller,
  double target, {
  double velocity = 0,
  double response = Motion.springResponse,
  double damping = 1,
}) async {
  final stiffness = math.pow(2 * math.pi / response, 2).toDouble();
  try {
    await controller
        .animateWith(
          SpringSimulation(
            SpringDescription(
              mass: 1,
              stiffness: stiffness,
              damping: 2 * damping * math.sqrt(stiffness),
            ),
            controller.value,
            target,
            velocity,
          ),
        )
        .orCancel;
    controller.value = target;
    return true;
  } on TickerCanceled {
    return false; // A new pointer takes over the live value.
  }
}
