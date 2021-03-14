import 'dart:developer';

import 'package:coulomb/widgets/cartesian.dart';
import 'package:coulomb/drawing.dart';
import 'package:coulomb/phis.dart';
import 'package:coulomb/util.dart';
import 'package:coulomb/widgets/charge.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

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
enum VisualizationQuality { low, medium, high }

class _ChargesContainerState extends State<ChargesContainer> {
  final _cartesianController = CartesianViewplaneController();
  final charges = [
    Charge(
      Vector2(-25, 10),
      10,
    ),
    Charge(Vector2(25, 10), -20)
  ];
  VisualizationType _type = VisualizationType.gradient;
  VisualizationType get type => _type;
  set type(VisualizationType type) => setState(() => _type = type);

  VisualizationQuality _quality = VisualizationQuality.medium;
  VisualizationQuality get quality => _quality;
  set quality(VisualizationQuality quality) {
    setState(() => _quality = quality);
    _field = null;
  }

  List<List<Vector2>> _field;
  List<List<Vector2>> get field => _field ??= walkField(charges, stepCount: () {
        switch (quality) {
          case VisualizationQuality.low:
            return 500;
          case VisualizationQuality.medium:
            return 1000;
          case VisualizationQuality.high:
            return 2000;
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
          child: ManagedListener(
            createManager: _createGestureManager,
            child: Cartesian(
              controller: _cartesianController,
              children: [
                GestureDetector(
                  onTapUp: _onAddCharge,
                  onScaleStart: _scaleStart,
                  onScaleUpdate: _scaleUpdate,
                  onScaleEnd: _scaleEnd,
                  child: SizedBox.expand(),
                  behavior: HitTestBehavior.translucent,
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
        PopupMenuButton(
          itemBuilder: (_) => VisualizationType.values
              .map((e) => PopupMenuItem<VisualizationType>(
                    value: e,
                    child: Text(e.toString()),
                  ))
              .toList(),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(type.toString()),
          ),
          onSelected: (t) => type = t,
        ),
        PopupMenuButton(
          itemBuilder: (_) => VisualizationQuality.values
              .map((e) => PopupMenuItem<VisualizationQuality>(
                    value: e,
                    child: Text(e.toString()),
                  ))
              .toList(),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(quality.toString()),
          ),
          onSelected: (q) => quality = q,
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

extension on Offset {
  Vector2 toVector2() => Vector2(dx, dy);
}

extension on Vector2 {
  Offset toOffset() => Offset(x, y);
}

extension on Vector4 {
  Vector2 toVector2() => Vector2(x, y);
}
