import 'dart:collection';
import 'dart:developer';
import 'dart:math';
import 'dart:ui';

import 'package:coulomb/drawing.dart';
import 'package:coulomb/main.dart';
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

  static const kMassSizeFactor = 100.0;

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

  void updateFixedCharges(void Function(List<Charge>) updates) {
    updates(_fixedCharges);
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

  final List<SimulatedObject> objects = [
    SimulatedObject(position: Vector2(0, 20))
  ];
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
    return Vector2(0, -10);
  }

  static final debug = [];

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
      print(o.position);
      // Check collision with ground
      if (!ground.isColliding(o)) {
        continue;
      }
      final surface = ground.surfaceFor(o);
      print(surface);
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

const simulationSpeed = 0.1;

class WorldSimulator extends StatefulWidget {
  @override
  _WorldSimulatorState createState() => _WorldSimulatorState();
}

class _WorldSimulatorState extends State<WorldSimulator>
    with WidgetsBindingObserver {
  final world = SimulatedWorld();
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  static const simulationStep = Duration(microseconds: 100);

  Duration? _previousFrameEpoch;

  void _onFrame(Duration epoch) {
    if (_previousFrameEpoch == null) {
      _previousFrameEpoch = epoch;
      setState(() {});
      return;
    }
    final dt = (epoch - _previousFrameEpoch!) * simulationSpeed;
    _previousFrameEpoch = epoch;

    final howManySteps = dt.inMicroseconds / simulationStep.inMicroseconds;
    final truncatedCount = howManySteps.toInt();
    final lastStep = howManySteps - truncatedCount;
    for (var i = 0; i < truncatedCount; i++) {
      world.update(dt * (1 / truncatedCount));
    }
    world.update(dt * lastStep);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance!.addPostFrameCallback(_onFrame);
    return Cartesian(
      eventChildren: [
        VectorField(
          charges: world.fieldCharges,
          type: VisualizationType.field,
        ),
        PointerHoverVectorViewer(
          vectorAt: world.electricFieldAtPoint,
        ),
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
            onRemove: () => setState(() => world.updateFixedCharges(
                  (charges) => charges.remove(e),
                )),
          ),
        ),
        ...world.bars.map(
          (e) => ModifiableChargedBar(
            bar: e,
            onUpdate: (bar) => setState(() => world.updateBar(
                  () => e.setFrom(bar),
                )),
            onRemove: () => setState(() => world.updateBars(
                  (bars) => bars.remove(e),
                )),
          ),
        ),
        ...world.objects.map((o) {
          //print('Flutter object with pos: ${o.position}');
          return ModifiableObject(object: o);
        }),
      ],
    );
  }
}
