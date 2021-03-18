import 'package:flutter/material.dart';
import '../phis.dart';

class PropController extends ChangeNotifier with PropScope {
  @override
  void onPropsChanged() {
    notifyListeners();
  }
}

mixin PropScope {
  /// The props that belong to THIS scope.
  /// Therefore, only changes that affect THEM should call [onPropsChanged].
  Set<Prop> _scopeProps = {};
  Map<Prop, Set<GetterProp>> _activePropDependendents = {};
  final _gettersBeingCalled = <GetterProp>{};

  void onPropsChanged();

  /// Record that self is an dependency for the getters which are currently
  /// being recorded
  void recordDependsOn(Prop self) {
    // an prop does not depend on itself
    final toBeAdded = _gettersBeingCalled.where((e) => e != self);

    final dependents = _activePropDependendents.putIfAbsent(self, () => {});
    dependents.addAll(toBeAdded);
  }

  /// Removes the getter prop from every dependency's dependent, because the
  /// getter will be called again and it may or may not depend on the same
  /// dependencies.
  void _removeDependent(GetterProp getter) {
    for (final e in _activePropDependendents.values) {
      e.remove(getter);
    }
  }

  /// Remove the previous dependency records for getterProp and start recording
  /// it.
  void startRecordingDependencies(GetterProp getterProp) {
    if (_parent != null) {
      _parent!.startRecordingDependencies(getterProp);
    }
    _removeDependent(getterProp);
    _gettersBeingCalled.add(getterProp);
  }

  /// Stop recording the dependencies for getterProp.
  void finishRecordingDependencies(GetterProp getterProp) {
    if (_parent != null) {
      _parent!.finishRecordingDependencies(getterProp);
    }
    _gettersBeingCalled.remove(getterProp);
  }

  /// Invalidate the values which depend on self
  void invalidateProp(
    Prop prop, {
    Set<PropScope>? alreadyNotified,
    bool notify = true,
  }) {
    assert(_scopeProps.contains(prop));
    final hadNotified =
        alreadyNotified != null && alreadyNotified.contains(this);

    (alreadyNotified ??= {}).add(this);

    if (!_activePropDependendents.containsKey(prop)) {
      return;
    }
    for (final dependent in _activePropDependendents[prop]!) {
      dependent.invalidate();
      final dependentScope = dependent._manager!;
      dependentScope.invalidateProp(
        dependent,
        alreadyNotified: alreadyNotified,
      );
    }
    if (!hadNotified && notify) {
      onPropsChanged();
    }
  }

  /// Called when [prop] changed
  void propChanged(MutableProp prop, {bool notify = true}) {
    invalidateProp(prop, notify: notify);
  }

  /// Called when [Prop.addManager] is called for [prop]
  void propAdded(Prop prop) {
    _scopeProps.add(prop);
  }

  /// Called when [Prop.dispose] is called for [prop]
  void propRemoved(Prop prop) {
    assert(_scopeProps.contains(prop));
    _scopeProps.remove(prop);
    if (prop is! GetterProp) {
      return;
    }
    _removeDependent(prop);
    if (_parent != null) {
      _parent!._removeDependent(prop);
    }
  }

  /// Subscope management

  PropScope? _parent;
  final _childScopes = <PropScope>{};

  void addSubscope(PropScope child) {
    child._parent ??= this;
    assert(child._parent == this);
    _childScopes.add(child);
  }

  void removeSubscope(PropScope child) {
    assert(child._parent == this);
    _childScopes.remove(child);
  }

  void disposeScope() {
    _childScopes.forEach((e) => e.disposeScope());
    _scopeProps.forEach((e) => e.dispose());
    _parent?.removeSubscope(this);
  }

  String scopeToString() {
    final buff = StringBuffer();

    final indentation = ' ';

    buff..writeln('{')..writeln(' props: [');
    _scopeProps
        .map((e) => e.toString())
        .bind((scope) => [indentation * 2, scope, ',\n'])
        .forEach(buff.write);
    buff
      ..write(' ],\n')
      ..writeln(' dependents: [');
    _activePropDependendents.entries
        .map((e) => '${e.key} -> ${e.value}')
        .bind((scope) => [indentation * 2, scope, ',\n'])
        .forEach(buff.write);
    buff
      ..write(' ],\n')
      ..writeln(' subscopes: [');
    _childScopes
        .map((o) => o.scopeToString())
        .bind((scope) => [scope, ','])
        .bind((s) => s.split('\n'))
        .bind((ln) => [indentation * 2, ln, '\n'])
        .forEach(buff.write);
    buff..write(' ]\n}');
    return buff.toString();
  }
}

abstract class Prop<T> {
  T call();

  PropScope? _manager;
  void addManager(PropScope manager) {
    assert(_manager == null);
    _manager = manager;
    manager.propAdded(this);
  }

  Set<Prop>? dependents() => _manager?._activePropDependendents[this];

  @mustCallSuper
  void dispose() {
    final m = _manager;
    _manager = null;
    if (m != null) {
      m.propRemoved(this);
    }
  }

  bool get isAttached => _manager != null;
  @override
  String toString() => '$runtimeType#${hashCode.toRadixString(16)}';
}

extension UpdateSelf<T> on MutableProp<T> {
  void update(void Function(T) update) {
    update(call());
    notifyDependents();
  }
}

abstract class MutableProp<T> extends Prop<T> {
  void set(T newValue, [bool notify = true]);
  void notifyDependents() {
    _manager!.invalidateProp(this);
    _manager?.onPropsChanged();
  }
}

class ValueProp<T> extends MutableProp<T> {
  T _value;

  ValueProp(T initialValue) : _value = initialValue;

  @override
  T call() {
    _manager?.recordDependsOn(this);
    return _value!;
  }

  @override
  void set(T newValue, [bool notify = true]) {
    if (newValue == _value) {
      return;
    }
    _value = newValue;
    _manager?.propChanged(this, notify: notify);
  }

  @override
  String toString() => '${super.toString()}{&$_value}';
}

class LateProp<T> extends ValueProp<T?> {
  LateProp() : super(null) {
    assert(null is! T);
  }

  @override
  T call() => super.call()!;

  @override
  void set(T? newValue, [bool notify = true]) =>
      super.set(newValue as T, notify);
  bool get isSet => _value != null;
  T? maybeGet() => _value;
}

class GetterProp<T> extends Prop<T> {
  final T Function()? create;

  GetterProp(this.create, [T? initial]) : _value = initial;

  T? _value;

  @override
  void addManager(PropScope manager) {
    super.addManager(manager);
  }

  T _create() {
    final mgr = _manager;
    if (mgr == null) {
      return create!();
    }
    mgr.startRecordingDependencies(this);
    final r = create!();
    mgr.finishRecordingDependencies(this);
    return r;
  }

  T call() {
    _manager?.recordDependsOn(this);
    final hasValue = _value != null;
    if (hasValue) {
      return _value as T;
    }

    wasInvalidated = false;
    return _value = _create();
  }

  void invalidate() {
    _value = null;
    wasInvalidated = true;
  }

  bool wasInvalidated = false;

  Set<Prop>? dependencies() => _manager?._activePropDependendents.entries
      .where((e) => e.value.contains(this))
      .map((e) => e.key)
      .toSet();
  @override
  String toString() => '${super.toString()}{&$_value}';
}

class ScopeProvider extends InheritedWidget {
  final PropScope scope;

  ScopeProvider({
    Key? key,
    required Widget child,
    required this.scope,
  }) : super(
          key: key,
          child: child,
        );

  @override
  bool updateShouldNotify(ScopeProvider oldWidget) => scope != oldWidget.scope;

  static PropScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ScopeProvider>()?.scope;
}

class PropBuilder<T> extends StatefulWidget {
  final PropScope? scope;
  final T Function() value;
  final Widget Function(BuildContext, T) builder;

  const PropBuilder({
    Key? key,
    this.scope,
    required this.value,
    required this.builder,
  }) : super(key: key);
  @override
  _PropBuilderState<T> createState() => _PropBuilderState<T>();
}

class _PropBuilderState<T> extends State<PropBuilder<T>> with PropScope {
  bool _building = false;
  GetterProp<T>? value;

  PropScope? oldScope;

  @override
  void onPropsChanged() {
    print('on props changed');
    if (!_building) {
      setState(() {});
    }
  }

  void dispose() {
    super.dispose();
    disposeScope();
  }

  void didUpdateWidget(PropBuilder<T> old) {
    super.didUpdateWidget(old);
    if (old.value == widget.value) {
      return;
    }
    value?.dispose();
    value = GetterProp(widget.value, value?._value);
  }

  @override
  Widget build(BuildContext context) {
    final scope = widget.scope ?? ScopeProvider.of(context)!;
    if (scope != oldScope) {
      value?.dispose();
      oldScope?.removeSubscope(this);
      scope.addSubscope(this);
      oldScope = scope;
      value = GetterProp<T>(widget.value)..addManager(this);
    }
    if (!value!.isAttached) {
      value!.addManager(this);
    }
    _building = true;
    final child = widget.builder(context, value!());
    _building = false;
    return child;
  }
}
