import 'package:coulomb/widgets/phis.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData.from(
          colorScheme: ColorScheme.light(
        primary: Colors.deepPurple,
        secondary: Colors.indigoAccent,
      )),
      darkTheme: ThemeData.from(
          colorScheme: ColorScheme.dark(
        primary: Colors.deepPurple[200]!,
        secondary: Colors.indigoAccent[200]!,
        background: Colors.grey[900]!,
      )),
      home: Scaffold(
        appBar: AppBar(
          title: Text('Campo elétrico'),
        ),
        body: WorldSimulator(),
      ),
    );
  }
}
