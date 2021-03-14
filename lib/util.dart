import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

abstract class PointerManager {
  void pointerCancel(PointerCancelEvent event);
}

abstract class PointerDragManager extends PointerManager {
  void pointerDown(PointerDownEvent event);

  void pointerMove(PointerMoveEvent event);

  void pointerUp(PointerUpEvent event);
}

abstract class PointerHoverManager extends PointerManager {
  void pointerHover(PointerHoverEvent event);
}

class PointerState {
  PointerHoverManager hoverManager;
  PointerDragManager dragManager;

  void pointerDown(PointerDownEvent event) {
    hoverManager?.pointerCancel(PointerCancelEvent(
      pointer: event.pointer,
      position: event.position,
      buttons: event.buttons,
    ));
    hoverManager = null;
    dragManager?.pointerDown(event);
  }

  void pointerCancel(PointerCancelEvent event) {
    hoverManager?.pointerCancel(event);
    dragManager?.pointerCancel(event);
    dragManager = null;
    hoverManager = null;
  }

  void pointerMove(PointerMoveEvent event) {
    dragManager?.pointerMove(event);
  }

  void pointerUp(PointerUpEvent event) {
    dragManager?.pointerUp(event);
    dragManager = null;
  }

  void pointerHover(PointerHoverEvent event) {
    hoverManager?.pointerHover(event);
  }

  void maybeCreate(
    PointerEvent event,
    PointerManager Function(PointerEvent) create,
  ) {
    if (event is PointerHoverEvent) {
      hoverManager ??= create(event);
    }
    if (event is PointerDownEvent) {
      dragManager ??= create(event);
    }
  }
}

class ManagedListener extends StatefulWidget {
  final PointerManager Function(PointerEvent) createManager;
  final Widget child;
  final HitTestBehavior behavior;

  const ManagedListener({
    Key key,
    this.createManager,
    this.child,
    this.behavior = HitTestBehavior.opaque,
  }) : super(key: key);
  @override
  _ManagedListenerState createState() => _ManagedListenerState();
}

class _ManagedListenerState extends State<ManagedListener> {
  final _state = <int, PointerState>{};

  void _pointerDown(PointerDownEvent event) => _state.putIfAbsent(
        event.pointer,
        () => PointerState(),
      )
        ..maybeCreate(event, widget.createManager)
        ..pointerDown(event);

  void _pointerCancel(PointerCancelEvent event) {
    _state[event.pointer].pointerCancel(event);
  }

  void _pointerMove(PointerMoveEvent event) =>
      _state[event.pointer].pointerMove(event);

  void _pointerUp(PointerUpEvent event) =>
      _state[event.pointer].pointerUp(event);

  void _pointerHover(PointerHoverEvent event) => _state.putIfAbsent(
        event.pointer,
        () => PointerState(),
      )
        ..maybeCreate(event, widget.createManager)
        ..pointerHover(event);

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _pointerDown,
      onPointerCancel: _pointerCancel,
      onPointerMove: _pointerMove,
      onPointerUp: _pointerUp,
      onPointerHover: _pointerHover,
      behavior: widget.behavior,
      child: widget.child,
    );
  }
}
