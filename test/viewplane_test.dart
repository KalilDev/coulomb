import 'package:coulomb/widgets/cartesian.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Viewplane', () {
    final viewSize = Size(2, 2);
    final viewCenter = Offset(1, 1);
    late CartesianViewplaneController plane;
    setUp(() {
      plane = CartesianViewplaneController();
    });

    test('throws before setting size', () {
      expect(() => plane.cartesianToLocal(viewCenter), throwsA(anything));
      expect(() => plane.localToCartesian(viewCenter), throwsA(anything));
    });
    test('Is centered after setting size', () {
      plane.setSize(viewSize);
      expect(plane.localToCartesian(viewCenter), Offset.zero);
      expect(plane.cartesianToLocal(Offset.zero), viewCenter);
      expect(plane.cartesianRect, Rect.fromLTRB(-1, -1, 1, 1));
    });
  });
}
