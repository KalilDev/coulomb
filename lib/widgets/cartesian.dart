import 'package:coulomb/widgets/props.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'package:coulomb/vec_conversion.dart';

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
  final List<Widget> children;
  final List<CartesianPainter> painters;
  final List<CartesianPainter> foregroundPainters;
  final CartesianViewplaneController? controller;

  const Cartesian({
    Key? key,
    this.children = const [],
    this.painters = const [],
    this.foregroundPainters = const [],
    this.controller,
  }) : super(key: key);

  @override
  _CartesianState createState() => _CartesianState();
}

class PropWidget extends StatefulWidget {
  final WidgetBuilder builder;

  const PropWidget({Key? key, required this.builder}) : super(key: key);
  @override
  _PropWidgetState createState() => _PropWidgetState();
}

class _PropWidgetState extends State<PropWidget> with PropScope {
  late final child = GetterProp<Widget>(() => Builder(builder: widget.builder))
    ..addManager(this);
  var _isInBuild = false;

  @override
  void onPropsChanged() {
    if (_isInBuild) {
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    _isInBuild = true;
    final result = child();
    _isInBuild = false;

    return result;
  }
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

  List<CartesianPainter> get _painters => [
        _CartesianPlanePainter(
          Theme.of(context).colorScheme.onSurface,
          Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        ),
        ...widget.painters,
      ];
  Widget _buildView(BuildContext context) => ClipRect(
        child: Stack(
          children: [
            for (final p in _painters) _wrapPainter(p),
            for (final w in widget.children) w,
            for (final p in widget.foregroundPainters) _wrapPainter(p),
          ],
        ),
      );

  AnimatedBuilder _wrapPainter(CartesianPainter p) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => CustomPaint(
        painter: _CartesianPainter(
          Matrix4.copy(_controller.transform),
          _controller.canvasInfo,
          p,
        ),
        size: _controller.viewSize,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      _controller.setSize(constraints.biggest);
      return _CartesianScope(
        controller: _controller,
        child: _buildView(context),
      );
    });
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
