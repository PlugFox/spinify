/// Notify about value changes.
/// {@nodoc}
typedef ValueChanged<T> = void Function(T value);

/// Notify about value changes.
/// {@nodoc}
final class CentrifugeValueNotifier<T> {
  /// Notify about value changes.
  /// {@nodoc}
  CentrifugeValueNotifier(this._value);

  /// Current value.
  /// {@nodoc}
  T get value => _value;
  T _value;

  /// Notify about value changes.
  /// {@nodoc}
  void notify(T value) {
    if (_value == value) return;
    _value = value;
    for (var i = 0; i < _listeners.length; i++) _listeners[i](value);
  }

  /// Listeners.
  /// {@nodoc}
  final List<ValueChanged<T>> _listeners = <ValueChanged<T>>[];

  /// Add listener.
  /// {@nodoc}
  void addListener(ValueChanged<T> listener) => _listeners.add(listener);

  /// Remove listener.
  /// {@nodoc}
  void removeListener(ValueChanged<T> listener) => _listeners.remove(listener);
}
