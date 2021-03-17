import 'package:coulomb/widgets/cartesian.dart';
import 'package:coulomb/drawing.dart';
import 'package:coulomb/phis.dart';
import 'package:coulomb/util.dart';
import 'package:coulomb/widgets/charge.dart';
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

class ChargesContainerController extends PropController {
  ChargesContainerController() {
    cartesianController().addListener(cartesianController.notifyDependents);
  }
  late final cartesianController = ValueProp(CartesianViewplaneController())
    ..addManager(this);
  late final charges = ValueProp([
    Charge(
      Vector2(-25, 10),
      10,
    ),
    Charge(Vector2(25, 10), -20)
  ])
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
}

class _ChargesContainerState extends State<ChargesContainer> {
  late final _controller = ChargesContainerController()
    ..addListener(() => setState(() {}));

  PointerManager? _createGestureManager(PointerEvent e) {
    if (e is PointerHoverEvent) {
      final pointer = e.pointer;
      return _VectorHoverManager(
        () =>
            _controller._pointerPositions.update((pos) => pos.remove(pointer)),
        (pos) => _controller._pointerPositions.update(
          (positions) => positions[pointer] = pos,
        ),
      );
    }
    if (e is PointerDownEvent) {
      return _TranslationDragManager(_controller.cartesianController());
    }
  }

  void _onAddCharge(TapUpDetails e) async {
    final chargePos =
        _controller.cartesianController().localToCartesian(e.localPosition);
    final chargeMod = await showDialog<double>(
      context: context,
      builder: (_) => ChargeDialog(),
    );
    if (chargeMod == null || chargeMod.isNaN) {
      return;
    }
    _controller.charges.update(
      (charges) => charges.add(Charge(
        chargePos.toVector2(),
        chargeMod,
      )),
    );
  }

  double? _baseScale;
  Offset? _initialTranslation;
  Offset? _initialFocalPoint;
  void _scaleEnd(ScaleEndDetails details) {
    _baseScale = null;
    _initialTranslation = null;
    _initialFocalPoint = null;
  }

  void _scaleUpdate(ScaleUpdateDetails details) {
    final focusDelta = details.localFocalPoint - _initialFocalPoint!;
    final translation = _initialTranslation! + focusDelta.scale(1, -1);
    final num scale = (_baseScale! * details.scale).clamp(0.4, 15.0);
    _controller
        .cartesianController()
        .setScaleAndTranslation(scale as double, translation);
  }

  void _scaleStart(ScaleStartDetails details) {
    _baseScale = _controller.cartesianController().scale;
    _initialTranslation = _controller.cartesianController().translation;
    _initialFocalPoint = details.localFocalPoint;
  }

  @override
  Widget build(BuildContext context) {
    final charges = _controller.charges();
    final type = _controller.type();
    final vectorPairs = _controller.vectorPairs();
    final field = _controller.field();
    final quality = _controller.quality();
    final distance = _controller.distance();
    final scale = _controller.cartesianController().scale;
    return Column(
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
                  onTapUp: _onAddCharge,
                  onScaleStart: _scaleStart,
                  onScaleUpdate: _scaleUpdate,
                  onScaleEnd: _scaleEnd,
                  behavior: HitTestBehavior.translucent,
                ),
              ),
              for (var i = 0; i < charges.length; i++)
                ModifiableCharge(
                  charge: charges[i],
                  onUpdate: (c) =>
                      _controller.charges.update((charges) => charges[i] = c),
                  onRemove: () => _controller.charges.update(
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
      ],
    );
  }
}

class _TranslationDragManager extends PointerDragManager {
  final CartesianViewplaneController controller;

  _TranslationDragManager(this.controller);

  Offset? _initialTranslation;

  @override
  void pointerCancel(PointerCancelEvent event) {
    if (_initialTranslation == null) {
      return;
    }
    controller.setTranslation(_initialTranslation!);
    _initialTranslation = null;
  }

  @override
  void pointerDown(PointerDownEvent event) {
    _initialTranslation = controller.translation;
  }

  @override
  void pointerMove(PointerMoveEvent event) {
    controller.addTranslation(event.delta.scale(1, -1));
  }

  @override
  void pointerUp(PointerUpEvent event) {
    _initialTranslation = null;
  }
}

class _VectorHoverManager extends PointerHoverManager {
  final void Function() removePointer;
  final void Function(Offset) update;

  _VectorHoverManager(
    this.removePointer,
    this.update,
  );

  @override
  void pointerCancel(PointerCancelEvent event) {
    removePointer();
  }

  @override
  void pointerHover(PointerHoverEvent event) {
    update(event.localPosition);
  }
}
