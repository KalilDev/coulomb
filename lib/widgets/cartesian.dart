import 'package:coulomb/widgets/props.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'package:coulomb/vec_conversion.dart';

import '../util.dart';
import 'workaround.dart';

class CartesianWidget extends StatelessWidget {
  final Offset position;
  final Widget child;

  const CartesianWidget({
    Key? key,
    required this.position,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = CartesianViewplaneController.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (_, child) {
        if (position.dx.isNaN ||
            position.dx.isInfinite ||
            position.dy.isNaN ||
            position.dy.isInfinite) {
          return Offstage(
            child: child,
          );
        }
        final m = Matrix4.identity()
          ..multiply(controller.transform)
          ..translate(position.dx, position.dy)
          ..scale(1.0, -1.0, 1.0);
        return Transform(
          transform: m,
          child: child,
        );
      },
      child: child,
    );
  }
}

class _CartesianScope extends InheritedWidget {
  final CartesianViewplaneController? controller;

  _CartesianScope({Key? key, this.controller, required Widget child})
      : super(key: key, child: child);

  @override
  bool updateShouldNotify(_CartesianScope oldWidget) =>
      controller != oldWidget.controller;
}

class Cartesian extends StatefulWidget {
  final List<Widget>? children;

  /// Children which will all receive the events from the plane
  final List<Widget>? eventChildren;
  final CartesianViewplaneController? controller;

  Cartesian(
      {Key? key,
      Widget? child,
      List<Widget>? children,
      this.controller,
      this.eventChildren})
      : assert(child == null || children == null),
        children = children ?? (child == null ? null : [child]),
        super(key: key);

  @override
  _CartesianState createState() => _CartesianState();
}

class CartesianViewplaneController extends ChangeNotifier with PropScope {
  late final _transform = LateProp<Matrix4>()..addManager(this);
  late final _untransform = GetterProp<Matrix4>(
    () => Matrix4.inverted(_transform()),
  )..addManager(this);
  late final _viewSize = LateProp<Size>()..addManager(this);
  late final _cartesianRect = GetterProp<Rect>(() {
    final origin = untransform.transform(Vector4E.pointZero());
    final end = untransform.transform(viewSize.toVector4Point());

    return Rect.fromPoints(origin.toOffset(), end.toOffset());
  })
    ..addManager(this);
  late final _scale = ValueProp<double>(1.0)..addManager(this);

  late final _translation = GetterProp<Offset>(() {
    final v = transform.getColumn(3);
    return Offset(v.x, -v.y);
  })
    ..addManager(this);
  late final _canvasInfo = GetterProp<CartesianCanvasInfo>(
    () => CartesianCanvasInfo(
      transform,
      untransform,
      cartesianRect,
      viewSize,
    ),
  )..addManager(this);

  Matrix4 get transform => _transform();
  Matrix4 get untransform => _untransform();
  Size get viewSize => _viewSize();
  Rect get cartesianRect => _cartesianRect();
  double get scale => _scale();
  Offset get translation => _translation();
  CartesianCanvasInfo get canvasInfo => _canvasInfo();

  static CartesianViewplaneController of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_CartesianScope>()!
      .controller!;

  void setSize(Size s) {
    final oldSize = _viewSize.maybeGet();
    _viewSize.set(s, false);
    if (oldSize == null) {
      _resetTransform(
        Offset(
          viewSize.width / 2,
          -viewSize.height / 2,
        ),
        doNotNotify: true, // Otherwise we would call setState inside of build
      );
    } else {
      final oldCenter = oldSize.center(Offset.zero);
      final newCenter = s.center(Offset.zero);
      final delta = newCenter - oldCenter;

      _resetTransform(translation.translate(delta.dx, delta.dy));
    }
  }

  void translateToCenter() {
    _resetTransform(
      Offset(
        viewSize.width / 2,
        -viewSize.height / 2,
      ),
    );
  }

  void setScaleAndTranslation(double s, Offset t) {
    _scale.set(s, false);
    _resetTransform(t);
  }

  void setScale(double s) {
    final oldTranslation = translation;
    final newTranslation = (translation / _scale()) * s;
    _scale.set(s, false);
    _resetTransform(newTranslation + (oldTranslation - newTranslation));
  }

  void setTranslation(Offset translation) {
    _resetTransform(translation);
  }

  void addTranslation(Offset delta) {
    setTranslation(translation + delta);
  }

  void _resetTransform(Offset translation, {bool doNotNotify = false}) {
    translation /= scale;
    _setTransform(
      Matrix4.diagonal3Values(scale, -scale, 1)
        ..translate(
          translation.dx,
          translation.dy,
        ),
      doNotNotify: doNotNotify,
    );
  }

  Offset cartesianToLocal(Offset coord, {bool isPoint = true}) => transform
      .transform(isPoint ? coord.toVector4Point() : coord.toVector4Distance())
      .toOffset();
  Offset localToCartesian(Offset coord, {bool isPoint = true}) => untransform
      .transform(isPoint ? coord.toVector4Point() : coord.toVector4Distance())
      .toOffset();

  void _setTransform(Matrix4 transform, {bool doNotNotify = false}) {
    _transform.set(transform, !doNotNotify);
  }

  @override
  void onPropsChanged() {
    notifyListeners();
  }
}

class _CartesianState extends State<Cartesian> {
  late CartesianViewplaneController _controller;
  void initState() {
    super.initState();
    _controller = widget.controller ?? CartesianViewplaneController();
  }

  void didUpdateWidget(Cartesian old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      _controller = widget.controller ?? CartesianViewplaneController();
    }
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
    final scale = (_baseScale! * details.scale).clamp(0.4, 15.0);
    _controller.setScaleAndTranslation(
      scale,
      translation,
    );
  }

  void _scaleStart(ScaleStartDetails details) {
    _baseScale = _controller.scale;
    _initialTranslation = _controller.translation;
    _initialFocalPoint = details.localFocalPoint;
  }

  PointerManager? _createTranslationManager(PointerEvent e) {
    if (e is PointerDownEvent) {
      return _TranslationDragManager(_controller);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      _controller.setSize(constraints.biggest);
      return _CartesianScope(
        controller: _controller,
        child: Stack(children: [
          CartesianPaint(
            painter: _CartesianPlanePainter(
              Theme.of(context).colorScheme.onSurface,
              Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          Positioned.fill(
            child: StackWithAllChildrenReceiveEvents(
              children: [
                Positioned.fill(
                  child: ManagedListener(
                    createManager: _createTranslationManager,
                    behavior: HitTestBehavior.translucent,
                  ),
                ),
                Positioned.fill(
                  child: GestureDetector(
                    onScaleStart: _scaleStart,
                    onScaleUpdate: _scaleUpdate,
                    onScaleEnd: _scaleEnd,
                    behavior: HitTestBehavior.translucent,
                  ),
                ),
                ...?widget.eventChildren
              ],
            ),
          ),
          ...?widget.children,
        ]),
      );
    });
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

class _CartesianPainter extends CustomPainter {
  final Matrix4 transform;
  final CartesianCanvasInfo canvasInfo;
  final CartesianPainter painter;

  const _CartesianPainter(
    this.transform,
    this.canvasInfo,
    this.painter,
  );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.transform(transform.storage);
    painter.paint(canvas, canvasInfo);
  }

  @override
  bool shouldRepaint(_CartesianPainter oldDelegate) =>
      canvasInfo != oldDelegate.canvasInfo ||
      transform != oldDelegate.transform ||
      oldDelegate.painter.runtimeType != painter.runtimeType ||
      oldDelegate.painter.shouldRepaint(painter);
}

class _CartesianPlanePainter extends CartesianPainter {
  final Color color;
  final Color gridColor;

  _CartesianPlanePainter(this.color, this.gridColor);

  @override
  void paint(Canvas canvas, CartesianCanvasInfo info) {
    final plane = info.plane;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.1;
    final gridTileWidth = info.size.shortestSide ~/ 100;
    /*for (var x = plane.left.floor();
        x <= plane.right.ceil();
        x += gridTileWidth) {
      canvas.drawLine(
        Offset(x.toDouble(), plane.top),
        Offset(x.toDouble(), plane.bottom),
        gridPaint,
      );
    }*/
    canvas.drawLine(Offset(plane.left, 0), Offset(plane.right, 0), paint);
    canvas.drawLine(Offset(0, plane.top), Offset(0, plane.bottom), paint);
  }

  @override
  bool shouldRepaint(_CartesianPlanePainter old) =>
      color != old.color || gridColor != old.gridColor;
}

class MultiCartesianPaint extends StatelessWidget {
  final List<CartesianPainter> painters;
  final Widget? child;
  final List<CartesianPainter>? foregroundPainters;
  final Clip? clip;

  const MultiCartesianPaint({
    Key? key,
    required this.painters,
    this.child,
    this.foregroundPainters,
    this.clip,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final widget = StackWithAllChildrenReceiveEvents(
      children: [
        ...painters.map((e) => CartesianPaint(painter: e)),
        if (child != null) Positioned.fill(child: child!),
        ...?foregroundPainters?.map((e) => CartesianPaint(painter: e))
      ],
    );
    if (clip == null) {
      return widget;
    }
    return ClipRect(
      child: widget,
      clipBehavior: clip!,
    );
  }
}

class CartesianPaint extends StatelessWidget {
  final CartesianPainter painter;
  final Widget? child;
  final Clip? clip;

  const CartesianPaint({
    Key? key,
    required this.painter,
    this.child,
    this.clip,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = CartesianViewplaneController.of(context);
    final widget = AnimatedBuilder(
      animation: controller,
      builder: (_, __) => CustomPaint(
        painter: _CartesianPainter(
          Matrix4.copy(controller.transform),
          controller.canvasInfo,
          painter,
        ),
        child: child,
        size: controller.viewSize,
      ),
    );
    if (clip == null) {
      return widget;
    }
    return ClipRect(
      child: child,
      clipBehavior: clip!,
    );
  }
}

class CartesianCanvasInfo {
  final Matrix4 transform;
  final Matrix4 untransform;
  final Rect plane;
  final Size size;

  const CartesianCanvasInfo._(
    this.transform,
    this.untransform,
    this.plane,
    this.size,
  );
  factory CartesianCanvasInfo(
          Matrix4 transform, Matrix4 untransform, Rect plane, Size size) =>
      CartesianCanvasInfo._(
        Matrix4.copy(transform),
        Matrix4.copy(untransform),
        plane,
        size,
      );
}

abstract class CartesianPainter {
  void paint(Canvas canvas, CartesianCanvasInfo info);
  bool shouldRepaint(covariant CartesianPainter old);
}
