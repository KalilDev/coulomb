import 'dart:collection';
import 'dart:math';
import 'dart:ui';

import 'package:coulomb/widgets/cartesian.dart';
import 'package:coulomb/widgets/charge.dart';
import 'package:coulomb/widgets/vector_field.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart';
import '../vec_conversion.dart';
import 'package:coulomb/vec_conversion.dart';

import '../phis.dart';
import 'charge_bar.dart';
import 'pointer_hover.dart';
import 'object.dart';

enum VisualizationType {
  gradient,
  field,
  none,
}

extension VisualizationTypeE on VisualizationType {
  String get text => _text[this]!;
  IconData get icon => _icon[this]!;

  static const _text = {
    VisualizationType.field: 'Gradiente de vetores',
    VisualizationType.gradient: 'Campo elétrico',
    VisualizationType.none: 'Nenhuma',
  };

  static const _icon = {
    VisualizationType.field: Icons.arrow_right_alt,
    VisualizationType.gradient: Icons.blur_linear,
    VisualizationType.none: Icons.highlight_off,
  };
}

enum VisualizationQuality { low, medium, high }

extension VisualizationQualityE on VisualizationQuality {
  String get text => _text[this]!;

  static const _text = {
    VisualizationQuality.low: 'Baixa',
    VisualizationQuality.medium: 'Média',
    VisualizationQuality.high: 'Alta',
  };
}

enum ToolType {
  fixedBar,
  fixedDot,
  object,
  none,
}

extension ToolTypeE on ToolType {
  String get text => _text[this]!;
  IconData get icon => _icon[this]!;

  static const _text = {
    ToolType.none: 'Navegar',
    ToolType.fixedDot: 'Carga circular fixa',
    ToolType.fixedBar: 'Carga em barra fixa',
    ToolType.object: 'Objeto físico',
  };

  static const _icon = {
    ToolType.none: Icons.near_me_outlined,
    ToolType.fixedDot: Icons.add_circle_outline,
    ToolType.fixedBar: Icons.add_box_outlined,
    ToolType.object: Icons.add_circle_rounded,
  };
}

class ChargedBar implements ChargedObject {
  final Vector2 position = Vector2.zero();
  double rotation;
  double totalCharge;

  ChargedBar(
    Vector2 initialPosition,
    this.rotation,
    this.totalCharge,
  ) {
    position.setFrom(initialPosition);
  }

  static const divisions = 10;
  static const widthPerCharge = 10;
  Vector2 get chargeUnitVec => Vector2(sin(rotation), cos(rotation));
  Vector2 get chargeUnitVecPerpendicular =>
      Vector2(sin(rotation - pi / 2), cos(rotation - pi / 2));

  Rect get viewRect {
    // cache the getter
    final chargeUnitVec = this.chargeUnitVec;

    final totalWidth = totalCharge.abs() * widthPerCharge;
    final chargeDistance = totalWidth / divisions;
    chargeUnitVec.scale(chargeDistance);
    final halfSide = chargeUnitVec.scaled(divisions / 2);
    final topLeft = position.clone()..add(-halfSide);
    final bottomRight = position.clone()
      ..add(halfSide)
      ..addScaled(chargeUnitVecPerpendicular, totalWidth / 10);

    return Rect.fromPoints(topLeft.toOffset(), bottomRight.toOffset());
  }

  Size get rectSize {
    final totalWidth = totalCharge.abs() * widthPerCharge;
    return Size(totalWidth, totalWidth / 10);
  }

  @override
  List<Charge> get charges {
    // cache the getter
    final chargeUnitVec = this.chargeUnitVec;

    // start at the 'left' most edge
    final toStart = (divisions - 1) / 2;
    final chargeDistance = (totalCharge.abs() * widthPerCharge) / divisions;
    final chargeFrac = totalCharge / divisions;
    chargeUnitVec.scale(chargeDistance);

    final result = <Charge>[];

    final start = chargeUnitVec.scaled(-toStart) + position;
    for (var vec = start, i = 0; i <= divisions; i++, vec += chargeUnitVec) {
      result.add(Charge(vec.clone(), chargeFrac));
    }

    return result;
  }

  ChargedBar copy() => ChargedBar(position.clone(), rotation, totalCharge);

  void setFrom(ChargedBar other) => this
    ..position.setFrom(other.position)
    ..rotation = other.rotation
    ..totalCharge = other.totalCharge;
}

class SimulatedObject
    implements ChargedObject, MovingObject, MassfulObject, CollidableObject {
  double charge;

  @override
  double mass;

  @override
  final Vector2 position;

  bool simulating = true;

  @override
  List<Charge> get charges => [Charge(position, charge)];

  SimulatedObject({
    this.charge = -0.1,
    required this.position,
    this.mass = 1.0,
    Vector2? initialVelocity,
  }) {
    if (initialVelocity != null) velocity.add(initialVelocity);
  }

  @override
  final Vector2 velocity = Vector2.zero();

  static const kMassSizeFactor = 10.0;

  double get diameter => kMassSizeFactor * mass;
  double get radius => diameter / 2;

  @override
  Rect get collisionRect => Rect.fromCenter(
        center: position.toOffset(),
        width: diameter,
        height: diameter,
      );

  @override
  Vector2 get center => position;
}

class GroundSurface extends CollidableSurface {
  final double height;

  GroundSurface(this.height);
  @override
  bool isColliding(CollidableObject collidable) {
    final collidableRect = collidable.collisionRect;
    if (collidableRect.bottom < height || collidableRect.top < height) {
      return true;
    }
    return false;
  }

  @override
  Vector2 surfaceFor(CollidableObject collidingObject) {
    final objHeight = collidingObject.collisionRect.height;
    return Vector2(collidingObject.center.x, height + objHeight / 2);
  }

  @override
  double factorForVelocity(Vector2 velocity) {
    // Get the direction
    final normal = velocity.normalized();
    // Get the angle from normal to a [0,-1] vector
    final angle = atan2(normal.y, normal.x) + (pi / 2);
    final frac = (angle / pi).abs();

    const direct = 0.4;
    final result = direct + lerpDouble(0.0, 0.4, frac / 2)!;
    //print('result: $result, frac: $frac');
    return result;
  }
}

class SimulatedWorld implements ISimulatedWorld {
  double simulationSpeed = 1.0;
  final List<ChargedBar> _bars = [
    ChargedBar(Vector2.zero(), pi / 2, 10),
    ChargedBar(Vector2(0, 30), pi / 2, -10),
  ];
  List<ChargedBar> get bars => UnmodifiableListView(_bars);

  final List<Charge> _fixedCharges = [
    Charge(
      Vector2(-50, 0),
      10,
    ),
    //Charge(Vector2(10, 0), 10),
  ];
  List<Charge> get fixedCharges => UnmodifiableListView(_fixedCharges);
  final List<SimulatedObject> _objects = [
    SimulatedObject(position: Vector2(0, 20))
  ];
  List<SimulatedObject> get objects => UnmodifiableListView(_objects);

  double gravity = 10.0;

  void reset() {
    _fixedCharges
      ..clear()
      ..addAll([
        Charge(Vector2(-50, 0), 10),
      ]);
    _bars
      ..clear()
      ..addAll([
        ChargedBar(Vector2.zero(), pi / 2, 10),
        ChargedBar(Vector2(0, 30), pi / 2, -10),
      ]);
    _objects
      ..clear()
      ..addAll([
        SimulatedObject(position: Vector2(0, 20)),
      ]);
    gravity = 10.0;
    _fieldCharges = null;
  }

  void updateFixedCharges(void Function(List<Charge>) updates) {
    updates(_fixedCharges);
    _fieldCharges = null;
  }

  void updateObjects(void Function(List<SimulatedObject>) updates) {
    updates(_objects);
    _fieldCharges = null;
  }

  void updateBars(void Function(List<ChargedBar>) updates) {
    updates(_bars);
    _fieldCharges = null;
  }

  void updateBar(void Function() updates) {
    updates();
    _fieldCharges = null;
  }

  final ground = GroundSurface(0);

  List<Charge> get allCharges => [
        ...bars.bind((e) => e.charges),
        ..._fixedCharges,
        ...objects.bind((e) => e.charges)
      ];

  List<Charge>? _fieldCharges;
  List<Charge> get fieldCharges => _fieldCharges ??= [
        ...bars.bind((e) => e.charges),
        ..._fixedCharges,
      ];

  @override
  Vector2 electricFieldAtPoint(Vector2 v) {
    return electricFieldAt(allCharges, v);
  }

  Vector2 electricFieldAtCharge(Charge c) {
    final charges = allCharges.where((charge) => charge != c).toList();
    return electricFieldAt(charges, c.position);
  }

  @override
  Vector2 gravitationalFieldAt(Vector2 v) {
    return Vector2(0, -gravity);
  }

  var simulationStep = Duration(milliseconds: 1);

  @override
  void update(Duration dt) {
    final dtInSecs = dt.inMicroseconds / 1000000;
    //print('step $dtInSecs');
    for (final o in objects) {
      if (!o.simulating) {
        continue;
      }
      final forces = [
        electricFieldAtCharge(o.charges.single) * o.charge,
        gravitationalFieldAt(o.position) * o.mass,
      ];
      final resultingForce = forces.fold<Vector2>(
        Vector2.zero(),
        (resulting, force) => resulting..add(force),
      );
      final acceleration = resultingForce.scaled(o.mass);
      final dv = acceleration.scaled(dtInSecs);

      final oldVelocity = o.velocity.clone();
      // Update velocity
      o.velocity.add(dv);
      // Update distance
      o.position.add(oldVelocity * dtInSecs);
      if (o.velocity.length >= 10) {
        //debugger();
      }
      //print(o.position);
      // Check collision with ground
      if (!ground.isColliding(o)) {
        continue;
      }
      final surface = ground.surfaceFor(o);
      //print(surface);
      //final surfaceDirection = (surface.clone() - o.position)..normalize();

      o.position.setFrom(surface);
      final dampening =
          ground.factorForVelocity(o.velocity.clone()).clamp(0.0, 1.0);
      o.velocity..scale(dampening);
      o.velocity..multiply(Vector2(1, -1));
      final v = () {}();
      v.toString();
    }
  }
}

class WorldSimulator extends StatefulWidget {
  @override
  _WorldSimulatorState createState() => _WorldSimulatorState();
}

class _WorldSimulatorState extends State<WorldSimulator>
    with WidgetsBindingObserver {
  final world = SimulatedWorld();
  final cartesianController = CartesianViewplaneController();
  final visualizationController = VectorFieldController();
  var tool = ToolType.none;
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget _labeledIcon(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 8.0,
          horizontal: 4.0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon),
            Text(label),
          ],
        ),
      );

  Widget _toolbar(BuildContext context) {
    return SideToolbar(
      width: 48,
      radius: BorderRadius.horizontal(right: Radius.circular(24)),
      alignment: Alignment.centerLeft,
      children: [
        _labeledIcon(
          context,
          icon: Icons.edit,
          label: 'Tool',
        ),
        EnumToggleButtons<ToolType>(
          builder: (_, e) => Tooltip(
            message: e.text,
            child: Icon(e.icon),
          ),
          values: ToolType.values,
          active: {tool},
          onTap: (t) => setState(() => tool = t),
          direction: Axis.vertical,
        ),
      ],
    );
  }

  Widget _zoomControl(BuildContext context) {
    const zoomStepIn = 1.3;
    const zoomStepOut = 1 / 1.3;
    return SideToolbar(
      width: 48,
      radius: BorderRadius.horizontal(left: Radius.circular(24)),
      alignment: Alignment.centerRight,
      children: [
        _labeledIcon(
          context,
          icon: Icons.zoom_out_map,
          label: 'Zoom',
        ),
        Divider(),
        Tooltip(
          message: 'Aumentar zoom',
          child: IconButton(
            icon: Icon(Icons.zoom_in),
            onPressed: () => cartesianController
                .setScale(cartesianController.scale * zoomStepIn),
          ),
        ),
        Tooltip(
          message: 'Diminuir zoom',
          child: IconButton(
            icon: Icon(Icons.zoom_out),
            onPressed: () => cartesianController
                .setScale(cartesianController.scale * zoomStepOut),
          ),
        ),
        Divider(),
        Tooltip(
          message: 'Resetar zoom',
          child: IconButton(
            icon: Icon(Icons.refresh_outlined),
            onPressed: () => cartesianController.setScale(1),
          ),
        ),
      ],
    );
  }

  Widget _simulationControl(BuildContext context) {
    return AnimatedBottomToolbar(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: Text(
                'Configurações da simulação',
                style: Theme.of(context).textTheme.headline5,
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 8.0),
            Text('Velocidade', style: Theme.of(context).textTheme.subtitle1),
            SizedBox(height: 4.0),
            Row(
              children: [
                Text(world.simulationSpeed.toStringAsFixed(2)),
                Expanded(
                  child: Slider(
                    value: world.simulationSpeed,
                    onChanged: (s) => setState(
                      () => world.simulationSpeed = s,
                    ),
                    min: 0.1,
                    max: 2.0,
                    label: world.simulationSpeed.toStringAsFixed(2),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      hiddenChild: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListView(
          children: [
            Text('Gravidade', style: Theme.of(context).textTheme.subtitle1),
            SizedBox(height: 4.0),
            Row(
              children: [
                Text(world.gravity.toStringAsFixed(2)),
                Expanded(
                  child: Slider(
                    value: world.gravity,
                    onChanged: (s) => setState(
                      () => world.gravity = s,
                    ),
                    min: 3.0,
                    max: 30.0,
                    label: world.gravity.toStringAsFixed(2),
                  ),
                ),
              ],
            ),
            Text('ΔT da simulação (µs)',
                style: Theme.of(context).textTheme.subtitle1),
            SizedBox(height: 4.0),
            Row(
              children: [
                Text(world.simulationStep.inMicroseconds.toString()),
                Expanded(
                  child: Slider(
                    value: world.simulationStep.inMicroseconds.toDouble(),
                    onChanged: (s) => setState(
                      () => world.simulationStep =
                          Duration(microseconds: s.toInt()),
                    ),
                    min: 100,
                    max: 16000,
                    label: world.simulationStep.inMicroseconds.toString(),
                  ),
                ),
              ],
            ),
            Text('Ferramentas', style: Theme.of(context).textTheme.subtitle1),
            SizedBox(height: 4.0),
            ButtonBar(
              alignment: MainAxisAlignment.start,
              children: [
                TextButton(
                    onPressed: () {
                      world.reset();
                      cartesianController.translateToCenter();
                    },
                    child: Text('Reiniciar')),
                TextButton(
                    onPressed: cartesianController.translateToCenter,
                    child: Text('Centralizar'))
              ],
            ),
            Text(
              'Configurações da visualização',
              style: Theme.of(context).textTheme.headline5,
              textAlign: TextAlign.center,
            ),
            Text('Tipo', style: Theme.of(context).textTheme.subtitle1),
            SizedBox(height: 4.0),
            EnumToggleButtons<VisualizationType>(
              active: {visualizationController.type()},
              builder: (_, e) => Tooltip(
                child: Icon(e.icon),
                message: e.text,
              ),
              values: VisualizationType.values,
              onTap: visualizationController.type.set,
            ),
            SizedBox(height: 8.0),
            Text('Qualidade do campo',
                style: Theme.of(context).textTheme.subtitle1),
            SizedBox(height: 4.0),
            EnumToggleButtons<VisualizationQuality>(
              active: {visualizationController.quality()},
              builder: (_, e) => Text(e.text),
              values: VisualizationQuality.values,
              onTap: visualizationController.quality.set,
            ),
            SizedBox(height: 8.0),
            Text('Distancia do campo',
                style: Theme.of(context).textTheme.subtitle1),
            SizedBox(height: 4.0),
            EnumToggleButtons<VisualizationQuality>(
              active: {visualizationController.distance()},
              builder: (_, e) => Text(e.text),
              values: VisualizationQuality.values,
              onTap: visualizationController.distance.set,
            ),
          ],
        ),
      ),
      radius: BorderRadius.vertical(top: Radius.circular(36)),
    );
  }

  Duration? _previousFrameEpoch;

  void _onFrame(Duration epoch) {
    if (_previousFrameEpoch == null) {
      _previousFrameEpoch = epoch;
      setState(() {});
      return;
    }
    final dt = (epoch - _previousFrameEpoch!) * world.simulationSpeed;
    _previousFrameEpoch = epoch;

    final howManySteps =
        (dt.inMicroseconds / world.simulationStep.inMicroseconds)
            .clamp(0.0, 16.0);
    final truncatedCount = howManySteps.toInt();
    final lastStep = howManySteps - truncatedCount;
    for (var i = 0; i < truncatedCount; i++) {
      world.update(dt * (1 / truncatedCount));
    }
    world.update(dt * lastStep);
    setState(() {});
  }

  void _addChargeAt(Offset pos) async {
    final chargeMod = await showDialog<double>(
      context: context,
      builder: (_) => ChargeDialog(),
    );
    if (chargeMod == null || chargeMod.isNaN) {
      return;
    }
    world.updateFixedCharges(
      (charges) => charges.add(Charge(
        pos.toVector2(),
        chargeMod,
      )),
    );
  }

  void _addBarAt(Offset pos) async {
    final chargeMod = await showDialog<double>(
      context: context,
      builder: (_) => ChargeDialog(),
    );
    if (chargeMod == null || chargeMod.isNaN) {
      return;
    }
    world.updateBars(
      (bars) => bars.add(ChargedBar(
        pos.toVector2(),
        0,
        chargeMod,
      )),
    );
  }

  void _addObjectAt(Offset pos) async {
    final data = await showDialog<ObjectDialogResult>(
      context: context,
      builder: (_) => ObjectDialog(),
    );
    if (data?.charge == null || data?.mass == null) {
      return;
    }
    data!;
    world.updateObjects(
      (objects) => objects.add(SimulatedObject(
        position: pos.toVector2(),
        charge: data.charge!,
        mass: data.mass!,
      )),
    );
  }

  void _useToolAt(TapUpDetails e) {
    final pos = cartesianController.localToCartesian(e.localPosition);
    switch (tool) {
      case ToolType.fixedBar:
        return _addBarAt(pos);
      case ToolType.fixedDot:
        return _addChargeAt(pos);
      case ToolType.object:
        return _addObjectAt(pos);
      case ToolType.none:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance!.addPostFrameCallback(_onFrame);
    return Cartesian(
      controller: cartesianController,
      eventChildren: [
        VectorField(
          charges: world.fieldCharges,
          controller: visualizationController,
        ),
        PointerHoverVectorViewer(
          vectorAt: world.electricFieldAtPoint,
        ),
        Positioned.fill(
          child: GestureDetector(
            onTapUp: _useToolAt,
          ),
        )
      ],
      children: [
        ...world.fixedCharges.map(
          (e) => ModifiableCharge(
              charge: e,
              onUpdate: (ne) => setState(
                    () => e
                      ..mod = ne.mod
                      ..position.setFrom(ne.position),
                  ),
              onRemove: () => setState(
                    () => world
                        .updateFixedCharges((charges) => charges.remove(e)),
                  )),
        ),
        ...world.bars.map(
          (e) => ModifiableChargedBar(
              bar: e,
              onUpdate: (bar) => setState(() => world.updateBar(
                    () => e.setFrom(bar),
                  )),
              onRemove: () => setState(
                    () => world.updateBars((bars) => bars.remove(e)),
                  )),
        ),
        ...world.objects.map(
          (o) => ModifiableObject(
              object: o,
              onRemove: () => setState(
                    () => world.updateObjects((objs) => objs.remove(e)),
                  )),
        ),
        _toolbar(context),
        _zoomControl(context),
        _simulationControl(context),
      ],
    );
  }
}

class EnumToggleButtons<T> extends StatelessWidget {
  const EnumToggleButtons({
    Key? key,
    required this.builder,
    this.active = const {},
    required this.values,
    this.onTap,
    this.direction = Axis.horizontal,
  });

  final Widget Function(BuildContext, T) builder;
  final Set<T> active;
  final List<T> values;
  final ValueChanged<T>? onTap;
  final Axis direction;

  @override
  Widget build(BuildContext context) {
    return ToggleButtons(
      children: values.map((e) => builder(context, e)).toList(),
      isSelected: values.map(active.contains).toList(),
      onPressed: (i) => onTap?.call(values[i]),
      direction: direction,
    );
  }
}

class AnimatedBottomToolbar extends StatefulWidget {
  final Widget child;
  final Widget hiddenChild;
  final BorderRadius radius;

  const AnimatedBottomToolbar({
    Key? key,
    required this.child,
    required this.hiddenChild,
    required this.radius,
  }) : super(key: key);
  @override
  _AnimatedSideToolbarState createState() => _AnimatedSideToolbarState();
}

class _AnimatedSideToolbarState extends State<AnimatedBottomToolbar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this,
        duration: Duration(
          milliseconds: 400,
        ));
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  void _toggle() {
    if (_controller.isDismissed) {
      _controller.forward();
      return;
    }
    _controller.reverse();
    return;
  }

  Widget _toggleButton() {
    return SizedBox(
      height: 32.0,
      width: double.infinity,
      child: InkWell(
        onTap: _toggle,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, child) =>
              Transform.rotate(angle: _controller.value * pi, child: child),
          child: FittedBox(
            fit: BoxFit.fitHeight,
            child: Icon(Icons.arrow_drop_up),
          ),
        ),
      ),
    );
  }

  Widget _hiddenWrapper() {
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    final sheetHeight = MediaQuery.of(context).size.height / 3;
    return LayoutBuilder(
      builder: (_, constraints) => AnimatedBuilder(
        animation: animation,
        builder: (_, child) => ClipRect(
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            height: sheetHeight * animation.value,
            child: child,
          ),
        ),
        child: OverflowBox(
          minWidth: constraints.minWidth,
          minHeight: sheetHeight,
          maxWidth: constraints.maxWidth,
          maxHeight: sheetHeight,
          child: widget.hiddenChild,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        shape: RoundedRectangleBorder(borderRadius: widget.radius),
        clipBehavior: Clip.antiAlias,
        elevation: 8.0,
        child: ConstrainedBox(
          constraints: BoxConstraints.loose(
              Size.fromHeight(MediaQuery.of(context).size.height)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _toggleButton(),
              widget.child,
              _hiddenWrapper(),
            ],
          ),
        ),
      ),
    );
  }
}

class SideToolbar extends StatelessWidget {
  final List<Widget> children;
  final AlignmentGeometry alignment;
  final BorderRadius radius;
  final double width;

  const SideToolbar({
    Key? key,
    required this.alignment,
    required this.radius,
    required this.width,
    required this.children,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: SizedBox(
        width: width,
        child: Material(
          shape: RoundedRectangleBorder(borderRadius: radius),
          clipBehavior: Clip.antiAlias,
          elevation: 8.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    );
  }
}
