import 'dart:math';

import 'package:coulomb/widgets/phis.dart';
import 'package:flutter/material.dart';

import '../phis.dart';
import '../util.dart';
import 'cartesian.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'package:coulomb/vec_conversion.dart';

import 'cartesian_movable.dart';
import 'charge.dart';

class ModifiableChargedBar extends StatefulWidget {
  final ChargedBar bar;
  final ValueChanged<ChargedBar>? onUpdate;
  final VoidCallback? onRemove;
  final CartesianViewplaneController? controller;

  const ModifiableChargedBar({
    Key? key,
    required this.bar,
    this.onUpdate,
    this.onRemove,
    this.controller,
  }) : super(key: key);
  @override
  _ModifiableChargedBarState createState() => _ModifiableChargedBarState();
}

class _ModifiableChargedBarState extends State<ModifiableChargedBar> {
  ChargedBar? _bar;
  ChargedBar get bar => _bar ?? widget.bar;

  VoidCallback _openChangeDialog(BuildContext context) => () async {
        final result = await showDialog<double>(
            context: context,
            builder: (_) => ChargeDialog(
                  initialValue: bar.totalCharge,
                ));
        if (result == null) {
          return;
        }

        if (result.isNaN) {
          widget.onRemove?.call();
          return;
        }

        widget.onUpdate?.call(ChargedBar(bar.position, bar.rotation, result));
        return;
      };

  @override
  Widget build(BuildContext context) {
    return CartesianMovableWidget(
      position: bar.position,
      onMoveEnd: (p) => widget.onUpdate?.call(bar.copy()..position.setFrom(p)),
      child: ChargedBarWidget(
        bar: bar,
        onTap: _openChangeDialog(context),
      ),
    );
  }
}

class ChargedBarWidget extends StatelessWidget with PreferredSizeWidget {
  final ChargedBar bar;
  final VoidCallback? onTap;

  const ChargedBarWidget({
    Key? key,
    required this.bar,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: bar.rotation - pi / 2,
      child: Material(
        elevation: 4.0,
        color: chargeColor(bar.totalCharge),
        child: InkWell(
          onTap: onTap,
          child: SizedBox.fromSize(
            size: bar.rectSize,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                bar.totalCharge.toString(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => bar.viewRect.size;
}
