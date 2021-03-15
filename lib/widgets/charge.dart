import 'package:flutter/material.dart';

import '../phis.dart';
import '../util.dart';
import 'cartesian.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'package:coulomb/vec_conversion.dart';

class ModifiableCharge extends StatefulWidget {
  final Charge charge;
  final ValueChanged<Charge> onUpdate;
  final VoidCallback onRemove;
  final CartesianViewplaneController controller;

  const ModifiableCharge({
    Key key,
    this.charge,
    this.onUpdate,
    this.onRemove,
    this.controller,
  }) : super(key: key);
  @override
  _ModifiableChargeState createState() => _ModifiableChargeState();
}

class ChargeDialog extends StatefulWidget {
  final double initialValue;

  const ChargeDialog({
    Key key,
    this.initialValue,
  }) : super(key: key);
  @override
  _ChargeDialogState createState() => _ChargeDialogState();
}

class _ChargeDialogState extends State<ChargeDialog> {
  TextEditingController controller;
  @override
  void initState() {
    controller = TextEditingController(
        text: widget.initialValue == null
            ? null
            : widget.initialValue.toString());
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
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
          //errorText: 'Carga inválida!',
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

class _ChargeDragManager extends PointerDragManager {
  final CartesianViewplaneController controller;
  final Charge initialCharge;
  final ValueChanged<Charge> onInternalUpdate;
  final ValueChanged<Charge> onChanged;

  _ChargeDragManager(
    this.controller,
    this.initialCharge,
    this.onInternalUpdate,
    this.onChanged,
  );
  Vector2 _position;

  @override
  void pointerCancel(PointerCancelEvent event) {
    onInternalUpdate(null);
  }

  @override
  void pointerDown(PointerDownEvent event) {
    onInternalUpdate(Charge(
      _position = initialCharge.position.clone(),
      initialCharge.mod,
    ));
  }

  @override
  void pointerMove(PointerMoveEvent e) {
    var point = Vector4(e.delta.dx, e.delta.dy, 0, 0);
    point = controller.untransform.transform(point);

    onInternalUpdate(Charge(
      _position..add(point.toVector2()),
      initialCharge.mod,
    ));
  }

  @override
  void pointerUp(PointerUpEvent event) {
    onChanged(Charge(_position, initialCharge.mod));
    onInternalUpdate(null);
  }
}

class _ModifiableChargeState extends State<ModifiableCharge> {
  Charge _charge;
  Charge get charge => _charge ?? widget.charge;
  Color get color => charge.mod > 0
      ? Colors.blue
      : charge.mod == 0
          ? Colors.grey
          : Colors.red;

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
          widget.onRemove();
          return;
        }

        widget.onUpdate(Charge(charge.position, result));
        return;
      };

  PointerDragManager _createDragManager(PointerEvent e) {
    if (e is PointerDownEvent) {
      return _ChargeDragManager(
        widget.controller ?? CartesianViewplaneController.of(context),
        widget.charge,
        (charge) => setState(() => _charge = charge),
        widget.onUpdate,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chargeRadius = charge.mod.abs().clamp(3.0, double.infinity);
    return CartesianWidget(
      position:
          charge.position.toOffset() - Offset(chargeRadius, -chargeRadius),
      child: Material(
        color: color,
        elevation: 4,
        shape: CircleBorder(),
        child: InkWell(
          customBorder: CircleBorder(),
          onTap: _openChangeDialog(context),
          child: ManagedListener(
            behavior: HitTestBehavior.opaque,
            createManager: _createDragManager,
            child: AbsorbPointer(
              child: SizedBox(
                height: 2 * chargeRadius,
                width: 2 * chargeRadius,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    charge.mod.toString(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
