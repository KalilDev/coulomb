import 'package:coulomb/widgets/phis.dart';
import 'package:flutter/material.dart';

import '../phis.dart';
import '../util.dart';
import 'cartesian.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'package:coulomb/vec_conversion.dart';

import 'charge.dart';

class CartesianMovableWidget extends StatefulWidget {
  final PreferredSizeWidget child;
  final Vector2 position;
  final VoidCallback? onMoveStart;
  final ValueChanged<Vector2>? onMove;
  final ValueChanged<Vector2> onMoveEnd;
  final CartesianViewplaneController? controller;

  CartesianMovableWidget({
    Key? key,
    required this.child,
    required this.position,
    this.onMoveStart,
    this.onMove,
    required this.onMoveEnd,
    this.controller,
  }) : super(key: key) {
    assert(child.preferredSize.isFinite);
  }
  @override
  _CartesianMovableWidgetState createState() => _CartesianMovableWidgetState();
}

class _CartesianMoveManager extends PointerDragManager {
  final CartesianViewplaneController controller;
  final Vector2 initialPosition;
  final VoidCallback onStart;
  final ValueChanged<Vector2> onUpdate;
  final ValueChanged<Vector2?> onEnd;

  _CartesianMoveManager(
    this.controller,
    this.initialPosition,
    this.onStart,
    this.onUpdate,
    this.onEnd,
  );
  late Vector2 _position;

  @override
  void pointerCancel(PointerCancelEvent event) {
    onEnd(null);
  }

  @override
  void pointerDown(PointerDownEvent event) {
    _position = initialPosition.clone();
    onStart();
  }

  @override
  void pointerMove(PointerMoveEvent e) {
    var point = Vector4(e.delta.dx, e.delta.dy, 0, 0);
    point = controller.untransform.transform(point);

    onUpdate(
      _position..add(point.toVector2()),
    );
  }

  @override
  void pointerUp(PointerUpEvent event) {
    onEnd(_position);
  }
}

class _CartesianMovableWidgetState extends State<CartesianMovableWidget> {
  Vector2? _position;
  Vector2 get position => _position ?? widget.position;

  PointerDragManager? _createDragManager(PointerEvent e) {
    if (e is PointerDownEvent) {
      return _CartesianMoveManager(
        widget.controller ?? CartesianViewplaneController.of(context),
        widget.position,
        () {
          setState(() => _position = widget.position.clone());
          widget.onMoveStart?.call();
        },
        (pos) {
          setState(() => _position = pos);
          widget.onMove?.call(pos);
        },
        (pos) {
          setState(() => _position = null);
          if (pos != null) {
            widget.onMoveEnd(pos);
          }
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.child.preferredSize;
    final halfSize = (size / 2).toOffset().scale(1, -1);
    return CartesianWidget(
      position: position.toOffset() - halfSize,
      child: SizedBox.fromSize(
        size: size,
        child: ManagedListener(
          behavior: HitTestBehavior.translucent,
          createManager: _createDragManager,
          child: AbsorbPointer(
            absorbing: _position != null,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
