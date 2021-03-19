import 'package:coulomb/drawing.dart';
import 'package:coulomb/widgets/cartesian.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:coulomb/vec_conversion.dart';
import '../util.dart';

class PointerHoverVectorViewer extends StatefulWidget {
  final Vector2 Function(Vector2) vectorAt;
  final CartesianViewplaneController? controller;

  const PointerHoverVectorViewer({
    Key? key,
    required this.vectorAt,
    this.controller,
  }) : super(key: key);
  @override
  _PointerHoverVectorViewerState createState() =>
      _PointerHoverVectorViewerState();
}

class _PointerHoverVectorViewerState extends State<PointerHoverVectorViewer> {
  late CartesianViewplaneController _controller;
  final _pointerPositions = <int, Offset>{};

  List<VectorPair>? _pairs;

  List<VectorPair> get pairs =>
      _pairs ??
      _pointerPositions.values
          .map(_controller.localToCartesian)
          .map((pos) => VectorPair(
                pos.toVector4Point(),
                widget.vectorAt(pos.toVector2()),
              ))
          .toList();

  PointerManager? _createGestureManager(PointerEvent e) {
    if (e is PointerHoverEvent && e.kind != PointerDeviceKind.touch) {
      final pointer = e.pointer;
      return _VectorHoverManager(
        () => setState(() {
          _pointerPositions.remove(pointer);
          _pairs = null;
        }),
        (pos) => setState(() {
          _pointerPositions[pointer] = pos;
          _pairs = null;
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    _controller = widget.controller ?? CartesianViewplaneController.of(context);
    return ManagedListener(
      createManager: _createGestureManager,
      behavior: HitTestBehavior.translucent,
      child: CartesianPaint(painter: VectorPairPainter(pairs)),
    );
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
