import 'dart:math';
import 'dart:ui';

import 'package:coulomb/widgets/cartesian.dart';
import 'package:coulomb/phis.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'package:collection/collection.dart';
import 'vec_conversion.dart';

class VectorPair {
  final Vector4 position;
  final Vector2 vector;

  VectorPair(this.position, this.vector);
}

class ChargeFieldPainter extends CartesianPainter {
  final List<Charge> charges;
  final List<List<Vector2>> field;
  final Color color;
  final double strokeWidth;
  ChargeFieldPainter(
    this.charges,
    this.field,
    this.color,
    this.strokeWidth,
  );

  static final rotate90 = Matrix2.rotation(pi / 2);

  @override
  void paint(Canvas canvas, CartesianCanvasInfo info) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final vertexBuffer = <Offset>[];

    final path = Path();
    for (final pathPoints in field) {
      var didInitialMove = false;
      Vector2? pointToMove;
      for (final p in pathPoints) {
        if (!info.plane.contains(p.toOffset())) {
          pointToMove = p;
          continue;
        }
        if (!didInitialMove) {
          path.moveTo(p.x, p.y);
          didInitialMove = true;
          pointToMove = null;
          continue;
        }
        if (pointToMove != null) {
          path.moveTo(pointToMove.x, pointToMove.y);
          pointToMove = null;
        }
        path.lineTo(p.x, p.y);
      }
/*
      var middlePoint = pathPoints[pathPoints.length ~/ 2];
      const arrowSize = 3.0;
      final fieldAtMiddle = electricFieldAt(charges, middlePoint);
      final fieldDirection = fieldAtMiddle.normalized();
      final perpendicular = rotate90 * fieldDirection * (arrowSize / 2);
      middlePoint = middlePoint + (fieldDirection / 2) * arrowSize;
      vertexBuffer.addAll([
        middlePoint.toOffset(),
        (middlePoint - fieldDirection * arrowSize + perpendicular).toOffset(),
        (middlePoint - fieldDirection * arrowSize - perpendicular).toOffset(),
      ]);*/
    }
    canvas.drawPath(path, paint);
    canvas.drawVertices(
      Vertices(VertexMode.triangles, vertexBuffer),
      BlendMode.srcOver,
      paint,
    );
  }

  final _chargeEquality = ListEquality<Charge>();

  @override
  bool shouldRepaint(ChargeFieldPainter oldDelegate) =>
      !_chargeEquality.equals(oldDelegate.charges, charges) &&
      field != oldDelegate.field;
}

final arrow = Path()
  ..moveTo(-1, 0.5)
  ..lineTo(0.25, 0.5)
  ..lineTo(0.25, 1)
  ..lineTo(1, 0)
  ..lineTo(0.25, -1)
  ..lineTo(0.25, -0.5)
  ..lineTo(-1, -0.5)
  ..close();

void paintVector(
  Canvas canvas,
  Vector4 position,
  Vector2 vector,
  Paint paint, [
  double sizeFactor = 1.0,
]) {
  final num scale = (log(vector.length) * 2).clamp(10.0, double.infinity);
  final angle = atan2(vector.y, vector.x);
  final m = Matrix4.identity()
    ..translate(position)
    ..scale(scale * sizeFactor)
    ..rotateZ(angle);

  canvas
    ..transform(m.storage)
    ..drawPath(arrow, paint)
    ..transform((m..invert()).storage);
}

class VectorFieldPainter extends CartesianPainter {
  final List<Charge> charges;

  VectorFieldPainter(this.charges);
  @override
  void paint(Canvas canvas, CartesianCanvasInfo info) {
    final gridSize = min(info.plane.width, info.plane.height) / 20;
    const factorPerSizeUnit = 0.01;

    final widthCount = (info.plane.width / gridSize).ceil();
    final heightCount = (info.plane.height / gridSize).ceil();
    final paint = Paint()..color = Colors.green;

    const forceEpsilon = 5;
    const epsilon2 = forceEpsilon * forceEpsilon;

    for (var x = 0; x <= widthCount; x++) {
      final dx = info.plane.left - info.plane.left % gridSize + x * gridSize;
      for (var y = 0; y <= heightCount; y++) {
        final dy = info.plane.top - info.plane.top % gridSize + y * gridSize;
        final pos = Vector2(dx, dy);
        final fieldAtPos = electricFieldAt(charges, pos);
        if (fieldAtPos.length2 < epsilon2) {
          continue;
        }
        paintVector(
          canvas,
          pos.toVector4Point(),
          fieldAtPos,
          paint,
          gridSize * factorPerSizeUnit,
        );
      }
    }
  }

  final _chargeEquality = ListEquality<Charge>();

  @override
  bool shouldRepaint(VectorFieldPainter oldDelegate) =>
      !_chargeEquality.equals(oldDelegate.charges, charges);
}

class VectorPairPainter extends CartesianPainter {
  final List<VectorPair> pairs;
  VectorPairPainter(this.pairs);

  @override
  void paint(Canvas canvas, CartesianCanvasInfo info) {
    final vecPaint = Paint()..color = Colors.orange;
    for (final pair in pairs) {
      var pos = pair.position;
      paintVector(canvas, pos, pair.vector, vecPaint);
    }
  }

  final _pairEquality = ListEquality<VectorPair>();

  @override
  bool shouldRepaint(VectorPairPainter oldDelegate) =>
      !_pairEquality.equals(pairs, oldDelegate.pairs);
}
