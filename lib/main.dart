import 'dart:developer';

import 'package:coulomb/widgets/cartesian.dart';
import 'package:coulomb/drawing.dart';
import 'package:coulomb/phis.dart';
import 'package:coulomb/util.dart';
import 'package:coulomb/widgets/charge.dart';
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

class _ChargesContainerState extends State<ChargesContainer> {
  final _cartesianController = CartesianViewplaneController();
  final charges = [
    Charge(
      Vector2(-25, 10),
      10,
    ),
    Charge(Vector2(25, 10), -20)
  ];
  VisualizationType _type = VisualizationType.field;
  VisualizationType get type => _type;
  set type(VisualizationType type) => setState(() => _type = type);

  VisualizationQuality _quality = VisualizationQuality.low;
  VisualizationQuality get quality => _quality;
  set quality(VisualizationQuality quality) {
    setState(() => _quality = quality);
    _field = null;
  }

  VisualizationQuality _distance = VisualizationQuality.low;
  VisualizationQuality get distance => _distance;
  set distance(VisualizationQuality distance) {
    _field = null;
    setState(() => _distance = distance);
  }

  double get _distanceFactor {
    switch (distance) {
      case VisualizationQuality.low:
        return 0.75;
      case VisualizationQuality.medium:
        return 1.0;
      case VisualizationQuality.high:
        return 1.8;
    }
  }

  List<List<Vector2>> _field;
  List<List<Vector2>> get field => _field ??= walkField(charges, stepCount: () {
        switch (quality) {
          case VisualizationQuality.low:
            return (500 * _distanceFactor).toInt();
          case VisualizationQuality.medium:
            return (1000 * _distanceFactor).toInt();
          case VisualizationQuality.high:
            return (2000 * _distanceFactor).toInt();
        }
      }(), stepSize: () {
        switch (quality) {
          case VisualizationQuality.low:
            return 3.0;
          case VisualizationQuality.medium:
            return 2.0;
          case VisualizationQuality.high:
            return 1.0;
        }
      }());

  final _pointerPositions = <int, Offset>{};

  List<VectorPair> get vectorPairs => _pointerPositions.values
      .map(_cartesianController.localToCartesian)
      .map((pos) => VectorPair(
            Vector4(pos.dx, pos.dy, 0, 1),
            electricFieldAt(charges, Vector2(pos.dx, pos.dy)),
          ))
      .toList();

  PointerManager _createGestureManager(PointerEvent e) {
    if (e is PointerHoverEvent) {
      final pointer = e.pointer;
      return _VectorHoverManager(
        () => setState(() => _pointerPositions.remove(pointer)),
        (pos) => setState(() => _pointerPositions[pointer] = pos),
      );
    }
    if (e is PointerDownEvent) {
      return _TranslationDragManager(_cartesianController);
    }
  }

  void _onAddCharge(TapUpDetails e) async {
    final chargePos = _cartesianController.localToCartesian(e.localPosition);
    final chargeMod = await showDialog<double>(
      context: context,
      builder: (_) => ChargeDialog(),
    );
    if (chargeMod == null || chargeMod.isNaN) {
      return;
    }
    charges.add(Charge(chargePos.toVector2(), chargeMod));
    _field = null;
  }

  double _baseScale;
  Offset _initialTranslation;
  Offset _initialFocalPoint;
  void _scaleEnd(ScaleEndDetails details) {
    _baseScale = null;
    _initialTranslation = null;
    _initialFocalPoint = null;
  }

  void _scaleUpdate(ScaleUpdateDetails details) {
    final focusDelta = details.localFocalPoint - _initialFocalPoint;
    final translation = _initialTranslation + focusDelta.scale(1, -1);
    final scale = (_baseScale * details.scale).clamp(0.4, 15.0);
    _cartesianController.setScaleAndTranslation(scale, translation);
  }

  void _scaleStart(ScaleStartDetails details) {
    _baseScale = _cartesianController.scale;
    _initialTranslation = _cartesianController.translation;
    _initialFocalPoint = details.localFocalPoint;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Cartesian(
            controller: _cartesianController,
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
                  onUpdate: (c) {
                    charges[i] = c;
                    _field = null;
                    setState(() {});
                  },
                  onRemove: () {
                    charges.removeAt(i);
                    _field = null;
                    setState(() {});
                  },
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
        AnimatedBuilder(
          animation: _cartesianController,
          builder: (_, __) => Slider(
            value: _cartesianController.scale,
            onChanged: (d) => _cartesianController.setScale(d),
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
          onSelected: (t) => type = t,
        ),
        EnumPopupButton<VisualizationQuality>(
          values: VisualizationQuality.values,
          buildItem: (_, e) => Text(e.text),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Qualidade da simulação: ${quality.text}'),
          ),
          onSelected: (q) => quality = q,
        ),
        EnumPopupButton<VisualizationQuality>(
          values: VisualizationQuality.values,
          buildItem: (_, e) => Text(e.text),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Distancia da simulação: ${distance.text}'),
          ),
          onSelected: (d) => distance = d,
        ),
      ],
    );
  }
}

class _TranslationDragManager extends PointerDragManager {
  final CartesianViewplaneController controller;

  _TranslationDragManager(this.controller);

  Offset _initialTranslation;

  @override
  void pointerCancel(PointerCancelEvent event) {
    controller.setTranslation(_initialTranslation);
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
