import 'dart:math';
import 'package:vector_math/vector_math_64.dart';

class Charge {
  final Vector2 position;
  final double mod;

  Charge(this.position, this.mod);
}

/// Calc the magnitude of an electric field originating from a single [source]
/// at an [target] point.
double singleElectricFieldMagAt(Charge source, Vector2 target) {
  const k0 = 9e5;
  final d2 = source.position.distanceToSquared(target);
  return k0 * (source.mod.abs() / d2);
}

/// Calc the electric field vec from an electric field originating from a single
/// [source] at an [target] point.
Vector2 singleElectricFieldAt(Charge source, Vector2 target) {
  final mag = singleElectricFieldMagAt(source, target);
  final direction = (target - source.position)..normalize();
  return direction * mag * source.mod.sign;
}

/// Calc the electric field vec from an electric field originating from many
/// [charges] at an [target] point.
Vector2 electricFieldAt(List<Charge> charges, Vector2 target) {
  var resultingVector = Vector2.zero();
  for (final charge in charges) {
    resultingVector += singleElectricFieldAt(charge, target);
  }
  return resultingVector;
}

bool _isInsideCharge(
        List<Charge> charges, Vector2 point, double epsilonSquared) =>
    charges.any((c) => c.position.distanceToSquared(point) <= epsilonSquared);

List<Vector2> walkFieldFromPoint(
  List<Charge> charges,
  Vector2 initialPoint, {
  required int stepCount,
  required bool walkBackwards,
  double stepSize = 1,
}) {
  final stepSquared = stepSize * stepSize;
  final result = <Vector2>[];
  Vector2 point = initialPoint;
  final forceSign = walkBackwards ? -1.0 : 1.0;

  var wasInsideCharge = false;
  while (stepCount > 0) {
    result.add(point);
    final fieldAtPoint = electricFieldAt(charges, point);
    final fieldDirection = fieldAtPoint..normalize();
    point += fieldDirection * stepSize * forceSign;

    final isInsideCharge = _isInsideCharge(charges, point, stepSquared);
    if (wasInsideCharge && isInsideCharge) {
      break;
    } else {
      wasInsideCharge = isInsideCharge;
    }

    stepCount--;
  }
  return result;
}

List<List<Vector2>> walkField(
  List<Charge> charges, {
  required int stepCount,
  int linesPerCoulomb = 5,
  double stepSize = 1,
}) {
  const int linesPerCoulomb = 5;
  const double epsilon = 0.2;
  final results = <List<Vector2>>[];
  for (final charge in charges) {
    final position = charge.position;
    final epsilonVec = Vector2(epsilon, 0);

    final lines = (linesPerCoulomb * charge.mod).abs().ceil();
    final singleLineTheta = (2 * pi) / lines;
    final m = Matrix2.identity();
    for (var i = 0; i < lines; i++) {
      m.setRotation(singleLineTheta * i);
      final initialPos = position + m * epsilonVec;
      results.add(walkFieldFromPoint(
        charges,
        initialPos,
        stepCount: stepCount,
        stepSize: stepSize,
        walkBackwards: charge.mod.sign < 0,
      ));
    }
  }
  return results;
}
