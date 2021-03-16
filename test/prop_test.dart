import 'dart:async';
import 'dart:developer';

import 'package:coulomb/widgets/props.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class Manager with PropScope {
  VoidCallback? onChanged;
  late final a = LateProp<double>()..addManager(this);
  late final b = ValueProp<double>(1.0)..addManager(this);
  late final ab = GetterProp<double>(() {
    getterCallCount++;
    return a() * b();
  })
    ..addManager(this);

  Manager([this.onChanged]);

  int getterCallCount = 0;

  @override
  void onPropsChanged() {
    onChanged?.call();
  }
}

class SubManager with PropScope {
  VoidCallback? onChanged;
  late final childProp = ValueProp<int>(1)..addManager(this);
  late final childGetter = GetterProp<int>(() {
    getterCallCount++;
    return (parent.ab() * childProp()).toInt();
  })
    ..addManager(this);
  int getterCallCount = 0;

  final Manager parent;

  SubManager(this.parent) {
    parent.addSubscope(this);
  }

  @override
  void onPropsChanged() {
    onChanged?.call();
  }
}

void main() {
  group('PropManager', () {
    late Manager m;
    late SubManager sm;
    setUp(() => sm = SubManager(m = Manager()));
    test('Basic functionality', () {
      expect(() => m.a(), throwsA(anything));
      expect(m.b(), 1.0);
      expect(() => m.a.set(1.0), returnsNormally);
      expect(m.ab(), 1.0);
    });
    test('onPropsChanged', () {
      m.onChanged = notCalled;
      m.a.set(1.0, false);
      m.b.set(1.0, false);

      m.ab();
      expect(m.getterCallCount, 1);

      var callCount = 0;
      m.onChanged = () => callCount++;
      expect(m.ab.wasInvalidated, false);

      m.ab();
      expect(m.getterCallCount, 1);
      expect(callCount, 0);

      m.a.set(2.0);
      expect(callCount, 1);
      expect(m.ab.wasInvalidated, true);

      expect(m.ab(), 2.0);
      expect(callCount, 1);
      expect(m.getterCallCount, 2);
      expect(m.ab.wasInvalidated, false);

      m.b.set(2.0);
      expect(callCount, 2);
      expect(m.ab.wasInvalidated, true);

      expect(m.ab(), 4.0);
      expect(m.getterCallCount, 3);
      expect(callCount, 2);
    });
    test('childScope', () async {
      m.a.set(1.0);
      m.ab();
      m.onChanged = notCalled;

      expect(sm.childGetter(), 1);
      expect(sm.getterCallCount, 1);

      expect(sm.childGetter(), 1);
      expect(sm.getterCallCount, 1);

      var mCompleter = Completer();
      var smCompleter = Completer();
      m.onChanged = mCompleter.complete;
      sm.onChanged = smCompleter.complete;

      m.a.set(2.0);
      await Future.wait([
        expectLater(
            mCompleter.future
                .timeout(Duration(milliseconds: 10))
                .then((value) => print('1')),
            completes),
        expectLater(
            smCompleter.future
                .timeout(Duration(milliseconds: 10))
                .then((value) => print('2')),
            completes)
      ]);

      expect(m.ab(), 2.0);
      expect(sm.childGetter(), 2);
      expect(sm.getterCallCount, 2);
    });
  });
}

void notCalled() {
  fail('Should not have been called');
}
