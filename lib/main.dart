import 'package:coulomb/widgets/cartesian.dart';
import 'package:coulomb/drawing.dart';
import 'package:coulomb/phis.dart';
import 'package:coulomb/util.dart';
import 'package:coulomb/widgets/charge.dart';
import 'package:coulomb/widgets/phis.dart';
import 'package:coulomb/widgets/props.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'vec_conversion.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: Scaffold(
        appBar: AppBar(
          title: Text('Campo elétrico'),
        ),
        body: ChargesContainer(),
      ),
    );
  }
}

class ChargesContainer extends StatefulWidget {
  @override
  _ChargesContainerState createState() => _ChargesContainerState();
}

enum VisualizationType { gradient, field }

extension on VisualizationType {
  String get text {
    switch (this) {
      case VisualizationType.gradient:
        return 'Gradiente de vetores';
      case VisualizationType.field:
        return 'Campo elétrico';
    }
  }
}

enum VisualizationQuality { low, medium, high }

extension on VisualizationQuality {
  String get text {
    switch (this) {
      case VisualizationQuality.low:
        return 'Baixa';
      case VisualizationQuality.medium:
        return 'Média';
      case VisualizationQuality.high:
        return 'Alta';
    }
  }
}

enum ToolType {
  fixedBar,
  fixedDot,
  object,
  none,
}

class ChargesContainerController extends PropController {
  ChargesContainerController() {
    cartesianController().addListener(cartesianController.notifyDependents);
  }
  late final cartesianController = ValueProp(CartesianViewplaneController())
    ..addManager(this);
  late final staticCharges = ValueProp([
    Charge(
      Vector2(-25, 10),
      10,
    ),
    Charge(Vector2(25, 10), -20)
  ])
    ..addManager(this);
  late final charges = GetterProp<List<Charge>>(() => staticCharges())
    ..addManager(this);
  late final type = ValueProp(VisualizationType.field)..addManager(this);
  late final quality = ValueProp(VisualizationQuality.low)..addManager(this);
  late final distance = ValueProp(VisualizationQuality.low)..addManager(this);
  late final GetterProp<double> _distanceFactor = GetterProp<double>(() {
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

  late final _pointerPositions = ValueProp(<int, Offset>{})..addManager(this);
  late final vectorPairs = GetterProp(() => _pointerPositions()
      .values
      .map(cartesianController().localToCartesian)
      .map((pos) => VectorPair(
            Vector4(pos.dx, pos.dy, 0, 1),
            electricFieldAt(charges(), Vector2(pos.dx, pos.dy)),
          ))
      .toList())
    ..addManager(this);
  late final toolType = ValueProp(ToolType.fixedDot)..addManager(this);
}

class _ChargesContainerState extends State<ChargesContainer> {
  late final _controller = ChargesContainerController()
    ..addListener(() => setState(() {}));

  void _addChargeAt(Offset pos, [bool bar = false]) async {
    final chargeMod = await showDialog<double>(
      context: context,
      builder: (_) => ChargeDialog(),
    );
    if (chargeMod == null || chargeMod.isNaN) {
      return;
    }
    _controller.staticCharges.update(
      (charges) => charges.add(Charge(
        pos.toVector2(),
        chargeMod,
      )),
    );
  }

  void _onToolUp(TapUpDetails e) {
    final pos =
        _controller.cartesianController().localToCartesian(e.localPosition);
    switch (_controller.toolType()) {
      case ToolType.fixedBar:
        // TODO: Handle this case.
        break;
      case ToolType.fixedDot:
        _addChargeAt(pos);
        break;
      case ToolType.object:
        // TODO: Handle this case.
        break;
      case ToolType.none:
        // TODO: Handle this case.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WorldSimulator();
    final staticCharges = _controller.staticCharges();
    final charges = _controller.charges();
    final type = _controller.type();
    final vectorPairs = _controller.vectorPairs();
    final field = _controller.field();
    final quality = _controller.quality();
    final distance = _controller.distance();
    final scale = _controller.cartesianController().scale;
    final toolType = _controller.toolType();
    /*return Column(
      children: [
        Expanded(
          child: Cartesian(
            controller: _controller.cartesianController(),
            children: [
              Positioned.fill(
                child: ManagedListener(
                  createManager: _createGestureManager,
                ),
              ),
              Positioned.fill(
                child: GestureDetector(
                  onTapUp: _onToolUp,
                  onScaleStart: _scaleStart,
                  onScaleUpdate: _scaleUpdate,
                  onScaleEnd: _scaleEnd,
                  behavior: HitTestBehavior.translucent,
                ),
              ),
              for (var i = 0; i < staticCharges.length; i++)
                ModifiableCharge(
                  charge: staticCharges[i],
                  onUpdate: (c) => _controller.staticCharges
                      .update((charges) => charges[i] = c),
                  onRemove: () => _controller.staticCharges.update(
                    (charges) => charges.removeAt(i),
                  ),
                ),
            ],
            painters: [
              if (type == VisualizationType.field)
                ChargeFieldPainter(
                    charges,
                    field,
                    Theme.of(context).brightness == Brightness.light
                        ? Colors.orange
                        : Colors.yellow,
                    0.4),
              if (type == VisualizationType.gradient)
                VectorFieldPainter(charges),
              VectorPairPainter(
                vectorPairs,
              ),
            ],
          ),
        ),
        PropBuilder<double>(
          scope: _controller,
          value: () => _controller.cartesianController().scale,
          builder: (_, __) => Slider(
            value: scale,
            onChanged: (d) => _controller.cartesianController().setScale(d),
            min: 0.4,
            max: 15.0,
          ),
        ),
        EnumPopupButton<VisualizationType>(
          values: VisualizationType.values,
          buildItem: (_, e) => Text(e.text),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Tipo de simulação: ${type.text}'),
          ),
          onSelected: (t) => _controller.type.set(t),
        ),
        EnumPopupButton<VisualizationQuality>(
          values: VisualizationQuality.values,
          buildItem: (_, e) => Text(e.text),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Qualidade da simulação: ${quality.text}'),
          ),
          onSelected: (q) => _controller.quality.set(q),
        ),
        EnumPopupButton<VisualizationQuality>(
          values: VisualizationQuality.values,
          buildItem: (_, e) => Text(e.text),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Distancia da simulação: ${distance.text}'),
          ),
          onSelected: (d) => _controller.distance.set(d),
        ),
        EnumPopupButton<ToolType>(
          values: ToolType.values,
          buildItem: (_, e) => Text(e.toString()),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Distancia da simulação: ${toolType.toString()}'),
          ),
          onSelected: (t) => _controller.toolType.set(t),
        ),
      ],
    );*/
  }
}
