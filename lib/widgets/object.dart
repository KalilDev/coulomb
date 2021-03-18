import 'package:coulomb/widgets/cartesian_movable.dart';
import 'package:coulomb/widgets/phis.dart';
import 'package:flutter/material.dart';
import 'package:coulomb/vec_conversion.dart';
import '../util.dart';
import 'cartesian.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

import 'charge.dart';

class ModifiableObject extends StatefulWidget {
  final SimulatedObject object;
  final VoidCallback? onRemove;
  final CartesianViewplaneController? controller;

  const ModifiableObject({
    Key? key,
    required this.object,
    this.onRemove,
    this.controller,
  }) : super(key: key);
  @override
  _ModifiableObjectState createState() => _ModifiableObjectState();
}

class ObjectDialog extends StatefulWidget {
  final double? initialMass;
  final double? initialCharge;

  const ObjectDialog({
    Key? key,
    this.initialMass,
    this.initialCharge,
  }) : super(key: key);
  @override
  _ChargeDialogState createState() => _ChargeDialogState();
}

class _ChargeDialogState extends State<ObjectDialog> {
  bool get isCreating =>
      widget.initialMass == null || widget.initialCharge == null;
  late TextEditingController mass;
  late TextEditingController charge;

  bool? _massValid;
  bool? _chargeValid;

  bool get isInvalid => _massValid == false || _chargeValid == false;

  @override
  void initState() {
    mass = TextEditingController(text: widget.initialMass?.toString());
    charge = TextEditingController(text: widget.initialCharge?.toString());
    mass.addListener(_validateMass);
    charge.addListener(_validateCharge);
    super.initState();
  }

  @override
  void dispose() {
    mass.dispose();
    charge.dispose();
    super.dispose();
  }

  void _validateMass() {
    _massValid = double.tryParse(mass.text) != null;
    setState(() {});
  }

  void _validateCharge() {
    _chargeValid = double.tryParse(charge.text) != null;
    setState(() {});
  }

  VoidCallback _exitWithData(BuildContext context) => () => Navigator.pop(
        context,
        ObjectDialogResult(
          double.tryParse(mass.text),
          double.tryParse(charge.text),
        ),
      );
  Widget _field({
    required String label,
    required bool? isValid,
    required TextEditingController controller,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: TextField(
          keyboardType: TextInputType.numberWithOptions(
            signed: true,
            decimal: true,
          ),
          decoration: InputDecoration(
            filled: true,
            labelText: label,
            errorText: isValid == false ? '$label inválida!' : null,
          ),
          controller: controller,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${isCreating ? 'Novo' : 'Alterar'} objeto simulado'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _field(
            label: 'Carga',
            isValid: _chargeValid,
            controller: charge,
          ),
          _field(
            label: 'Massa',
            isValid: _massValid,
            controller: mass,
          ),
        ],
      ),
      actions: [
        if (!isCreating)
          TextButton(
              onPressed: () =>
                  Navigator.pop(context, ObjectDialogResult.delete()),
              child: Text('REMOVER')),
        TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text('CANCELAR')),
        TextButton(
          onPressed: isInvalid ? null : _exitWithData(context),
          child: Text('OK'),
        ),
      ],
    );
  }
}

class ObjectDialogResult {
  final double? mass;
  final double? charge;
  final bool delete;

  ObjectDialogResult.delete()
      : mass = null,
        charge = null,
        delete = true;
  ObjectDialogResult(this.mass, this.charge) : delete = false;
}

class _ModifiableObjectState extends State<ModifiableObject> {
  SimulatedObject get object => widget.object;
  VoidCallback _openChangeDialog(BuildContext context) => () async {
        final obj = widget.object;
        obj.simulating = false;
        final result = await showDialog<ObjectDialogResult>(
            context: context,
            builder: (_) => ObjectDialog(
                  initialMass: obj.mass,
                  initialCharge: obj.charge,
                ));
        if (result == null) {
          obj.simulating = true;
          return;
        }

        if (result.delete) {
          widget.onRemove!();
          return;
        }

        obj
          ..charge = result.charge ?? obj.charge
          ..mass = result.mass ?? obj.mass;
        obj.simulating = true;
        return;
      };

  late DateTime lastContact;
  final lastVelocities = <Vector2>[];

  @override
  void _onMoveEnd(Vector2? pos) {
    if (pos == null) {
      object.simulating = true;
      object.velocity.setZero();
      lastVelocities.clear();
      return;
    }
    final taken = lastVelocities.reversed.take(10).toList();
    object.velocity.setZero();
    for (final partial in taken) {
      object.velocity.add(partial..scale(simulationSpeed / taken.length));
    }
    object.simulating = true;
    lastVelocities.clear();
  }

  @override
  void _onMoveStart() {
    lastVelocities.clear();
    object.simulating = false;
    lastContact = DateTime.now();
  }

  @override
  void _onMove(Vector2 pos) {
    final delta = pos.clone() - object.position;

    object.position.setFrom(pos);

    // Calc time delta
    final deltaT = DateTime.now().difference(lastContact);
    final dt = deltaT.inMicroseconds / 1000000;

    object.position.add(delta);
    lastContact = DateTime.now();

    lastVelocities.add(delta / dt);
  }

  @override
  Widget build(BuildContext context) {
    return CartesianMovableWidget(
      child: SimulatedObjectWidget(
        object: object,
        onTap: _openChangeDialog(context),
      ),
      position: object.position,
      onMoveStart: _onMoveStart,
      onMove: _onMove,
      onMoveEnd: _onMoveEnd,
    );
  }
}

class SimulatedObjectWidget extends StatelessWidget with PreferredSizeWidget {
  final SimulatedObject object;
  final VoidCallback? onTap;

  const SimulatedObjectWidget({
    Key? key,
    required this.object,
    this.onTap,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Material(
      color: chargeColor(object.charge),
      elevation: 4,
      shape: CircleBorder(),
      child: SizedBox.fromSize(
        size: preferredSize,
        child: InkWell(
          customBorder: CircleBorder(),
          onTap: onTap,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Mass: ${object.mass}\n'
              'Charge: ${object.charge}',
            ),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => object.collisionRect.size;
}
