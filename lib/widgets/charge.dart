import 'package:flutter/material.dart';

import '../phis.dart';
import 'cartesian.dart';

import 'cartesian_movable.dart';

Color chargeColor(double charge) => charge > 0
    ? Colors.blue
    : charge == 0
        ? Colors.grey
        : Colors.red;

class ChargeDialog extends StatefulWidget {
  final double? initialValue;

  const ChargeDialog({
    Key? key,
    this.initialValue,
  }) : super(key: key);
  @override
  _ChargeDialogState createState() => _ChargeDialogState();
}

class _ChargeDialogState extends State<ChargeDialog> {
  late TextEditingController controller;
  bool? _chargeValid;
  @override
  void initState() {
    controller = TextEditingController(text: widget.initialValue?.toString());
    controller.addListener(_validateCharge);
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _validateCharge() {
    _chargeValid = double.tryParse(controller.text) != null;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.initialValue == null ? 'Nova' : 'Alterar'} carga'),
      content: TextField(
        keyboardType: TextInputType.numberWithOptions(
          signed: true,
          decimal: true,
        ),
        decoration: InputDecoration(
          filled: true,
          labelText: 'Carga',
          errorText: _chargeValid == false ? 'Carga inválida!' : null,
        ),
        controller: controller,
        onSubmitted: (r) =>
            Navigator.pop(context, double.tryParse(r) ?? widget.initialValue),
      ),
      actions: [
        if (widget.initialValue != null)
          TextButton(
              onPressed: () => Navigator.pop(context, double.nan),
              child: Text('REMOVER')),
        TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text('CANCELAR')),
        TextButton(
            onPressed: () => Navigator.pop(context,
                double.tryParse(controller.value.text) ?? widget.initialValue),
            child: Text('OK')),
      ],
    );
  }
}

class ModifiableCharge extends StatefulWidget {
  final Charge charge;
  final ValueChanged<Charge>? onUpdate;
  final VoidCallback? onRemove;
  final CartesianViewplaneController? controller;

  const ModifiableCharge({
    Key? key,
    required this.charge,
    this.onUpdate,
    this.onRemove,
    this.controller,
  }) : super(key: key);
  @override
  _ModifiableChargeState createState() => _ModifiableChargeState();
}

class _ModifiableChargeState extends State<ModifiableCharge> {
  Charge? _charge;
  Charge get charge => _charge ?? widget.charge;

  VoidCallback _openChangeDialog(BuildContext context) => () async {
        final result = await showDialog<double>(
            context: context,
            builder: (_) => ChargeDialog(
                  initialValue: charge.mod,
                ));
        if (result == null) {
          return;
        }

        if (result.isNaN) {
          widget.onRemove?.call();
          return;
        }

        widget.onUpdate?.call(Charge(charge.position, result));
        return;
      };

  @override
  Widget build(BuildContext context) {
    return CartesianMovableWidget(
      position: charge.position,
      onMoveEnd: (p) =>
          widget.onUpdate?.call(charge.copy()..position.setFrom(p)),
      child: ChargeWidget(
        charge: charge,
        onTap: _openChangeDialog(context),
      ),
    );
  }
}

class ChargeWidget extends StatelessWidget with PreferredSizeWidget {
  final Charge charge;
  final VoidCallback? onTap;

  const ChargeWidget({
    Key? key,
    required this.charge,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2.0,
      color: chargeColor(charge.mod),
      shape: CircleBorder(),
      child: InkWell(
        onTap: onTap,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            charge.mod.toString(),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize {
    final chargeRadius = charge.mod.abs().clamp(3.0, double.infinity);
    return Size.square(chargeRadius * 2);
  }
}
