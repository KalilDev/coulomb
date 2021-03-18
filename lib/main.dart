import 'package:coulomb/widgets/cartesian.dart';
import 'package:coulomb/drawing.dart';
import 'package:coulomb/phis.dart';
import 'package:coulomb/util.dart';
import 'package:coulomb/widgets/charge.dart';
import 'package:coulomb/widgets/phis.dart';
import 'package:coulomb/widgets/props.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'vec_conversion.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: Scaffold(
        appBar: AppBar(
          title: Text('Campo elétrico'),
        ),
        body: WorldSimulator(),
      ),
    );
  }
}

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
