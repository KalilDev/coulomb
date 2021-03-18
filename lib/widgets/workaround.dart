import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class StackWithAllChildrenReceiveEvents extends Stack {
  StackWithAllChildrenReceiveEvents({
    Key? key,
    AlignmentDirectional alignment = AlignmentDirectional.topStart,
    TextDirection textDirection = TextDirection.ltr,
    StackFit fit = StackFit.loose,
    Clip clipBehavior = Clip.none,
    List<Widget> children = const <Widget>[],
  }) : super(
          key: key,
          alignment: alignment,
          textDirection: textDirection,
          fit: fit,
          clipBehavior: clipBehavior,
          children: children,
        );

  bool _debugCheckHasDirectionality(BuildContext context) {
    if (alignment is AlignmentDirectional && textDirection == null) {
      assert(
        debugCheckHasDirectionality(context,
            why: 'to resolve the \'alignment\' argument',
            hint: alignment == AlignmentDirectional.topStart
                ? 'The default value for \'alignment\' is AlignmentDirectional.topStart, which requires a text direction.'
                : null,
            alternative:
                'Instead of providing a Directionality widget, another solution would be passing a non-directional \'alignment\', or an explicit \'textDirection\', to the $runtimeType.'),
      );
    }
    return true;
  }

  @override
  RenderStack createRenderObject(BuildContext context) {
    assert(_debugCheckHasDirectionality(context));
    return RenderStackWithAllChildrenReceiveEvents(
      alignment: alignment,
      textDirection: textDirection ?? Directionality.maybeOf(context),
      fit: fit,
      clipBehavior: overflow == Overflow.visible ? Clip.none : clipBehavior,
    );
  }

  @override
  void updateRenderObject(BuildContext context,
      RenderStackWithAllChildrenReceiveEvents renderObject) {
    assert(_debugCheckHasDirectionality(context));
    renderObject
      ..alignment = alignment
      ..textDirection = textDirection ?? Directionality.maybeOf(context)
      ..fit = fit
      ..clipBehavior = overflow == Overflow.visible ? Clip.none : clipBehavior;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
        .add(DiagnosticsProperty<AlignmentGeometry>('alignment', alignment));
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection,
        defaultValue: null));
    properties.add(EnumProperty<StackFit>('fit', fit));
    properties.add(EnumProperty<Clip>('clipBehavior', clipBehavior,
        defaultValue: Clip.hardEdge));
  }
}

class RenderStackWithAllChildrenReceiveEvents extends RenderStack {
  RenderStackWithAllChildrenReceiveEvents({
    List<RenderBox>? children,
    AlignmentGeometry alignment = AlignmentDirectional.topStart,
    TextDirection? textDirection,
    StackFit fit = StackFit.loose,
    Clip clipBehavior = Clip.none,
  }) : super(
          alignment: alignment,
          textDirection: textDirection,
          fit: fit,
          clipBehavior: clipBehavior,
          children: children,
        );

  bool allCdefaultHitTestChildren(HitTestResult result,
      {required Offset position}) {
    // the x, y parameters have the top left of the node's box as the origin
    RenderBox? child = lastChild;
    while (child != null) {
      final childParentData = child.parentData as StackParentData;
      child.hitTest(result as BoxHitTestResult,
          position: position - childParentData.offset);
      child = childParentData.previousSibling;
    }
    return false;
  }

  @override
  bool hitTestChildren(HitTestResult result, {required Offset position}) {
    return allCdefaultHitTestChildren(result, position: position);
  }
}
