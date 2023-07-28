import 'package:meta/meta.dart';

/// Notify about value changes.
/// {@nodoc}
typedef ValueChanged<T> = void Function(T value);

/// Notify about value changes.
/// {@nodoc}
@internal
abstract interface class CentrifugeValueListenable<T> {
  /// Current value.
  /// {@nodoc}
  T get value;

  /// Add listener.
  /// {@nodoc}
  void addListener(ValueChanged<T> listener);

  /// Remove listener.
  /// {@nodoc}
  void removeListener(ValueChanged<T> listener);
}

/// Notify about value changes.
/// {@nodoc}
@internal
final class CentrifugeValueNotifier<T> implements CentrifugeValueListenable<T> {
  /// Notify about value changes.
  /// {@nodoc}
  CentrifugeValueNotifier(this._value);

  @override
  T get value => _value;
  T _value;

  /// Notify about value changes.
  /// {@nodoc}
  bool notify(T value) {
    if (_value == value) return false;
    _value = value;
    for (var i = 0; i < _listeners.length; i++) _listeners[i](value);
    return true;
  }

  /// Listeners.
  /// {@nodoc}
  final List<ValueChanged<T>> _listeners = <ValueChanged<T>>[];

  @override
  void addListener(ValueChanged<T> listener) => _listeners.add(listener);

  @override
  void removeListener(ValueChanged<T> listener) => _listeners.remove(listener);
}
