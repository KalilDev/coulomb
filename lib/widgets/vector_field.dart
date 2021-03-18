import 'package:coulomb/drawing.dart';
import 'package:coulomb/main.dart';
import 'package:coulomb/widgets/cartesian.dart';
import 'package:coulomb/widgets/props.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart';
import '../phis.dart';

class VectorField extends StatefulWidget {
  final List<Charge> charges;
  final VectorFieldController controller;

  const VectorField({
    Key? key,
    required this.charges,
    required this.controller,
  }) : super(key: key);

  @override
  _VectorFieldState createState() => _VectorFieldState();
}

class VectorFieldController extends PropController {
  late final charges = LateProp<List<Charge>>()..addManager(this);
  late final quality = ValueProp<VisualizationQuality>(VisualizationQuality.low)
    ..addManager(this);
  late final distance =
      ValueProp<VisualizationQuality>(VisualizationQuality.low)
        ..addManager(this);
  late final _distanceFactor = GetterProp<double>(() {
    switch (distance()) {
      case VisualizationQuality.low:
        return 0.75;
      case VisualizationQuality.medium:
        return 1.0;
      case VisualizationQuality.high:
        return 1.8;
      default:
        throw UnimplementedError();
    }
  })
    ..addManager(this);
  late final field =
      GetterProp<List<List<Vector2>>>(() => walkField(charges(), stepCount: () {
            switch (quality()) {
              case VisualizationQuality.low:
                return (500 * _distanceFactor()).toInt();
              case VisualizationQuality.medium:
                return (1000 * _distanceFactor()).toInt();
              case VisualizationQuality.high:
                return (2000 * _distanceFactor()).toInt();
              default:
                throw UnimplementedError();
            }
          }(), stepSize: () {
            switch (quality()) {
              case VisualizationQuality.low:
                return 3.0;
              case VisualizationQuality.medium:
                return 2.0;
              case VisualizationQuality.high:
                return 1.0;
              default:
                throw UnimplementedError();
            }
          }()))
        ..addManager(this);
  late final type = ValueProp(VisualizationType.field)..addManager(this);
}

bool listEqualsNotIdentical<T>(List<T>? a, List<T>? b) {
  if (a == null) return b == null;
  if (b == null || a.length != b.length) return false;
  for (int index = 0; index < a.length; index += 1) {
    if (a[index] != b[index]) return false;
  }
  return true;
}

class _VectorFieldState extends State<VectorField> {
  late final controller = widget.controller;
  void initState() {
    super.initState();
    controller.charges.set(widget.charges.map((e) => e.copy()).toList(), false);

    controller.addListener(() {
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(VectorField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(controller.charges(), widget.charges)) {
      controller.charges.set(widget.charges.map((e) => e.copy()).toList());
    }
  }

  CartesianPainter _painter() {
    switch (controller.type()) {
      case VisualizationType.field:
        return ChargeFieldPainter(
            controller.charges(), controller.field(), Color(0xFFcccc00), 1.0);
      case VisualizationType.gradient:
        return VectorFieldPainter(controller.charges());
      default:
        throw UnimplementedError();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (controller.type() == VisualizationType.none) {
      return SizedBox();
    }
    return CartesianPaint(painter: _painter());
  }
}
