/// Notify about value changes.
typedef ValueChanged<T> = void Function(T value);

/// Notify about value changes.
abstract interface class SpinifyListenable<T> {
  /// Add listener.
  void addListener(ValueChanged<T> listener);

  /// Remove listener.
  void removeListener(ValueChanged<T> listener);
}

/// Notify about value changes.
final class SpinifyChangeNotifier<T> implements SpinifyListenable<T> {
  /// Notify about value changes.
  SpinifyChangeNotifier();

  /// Notify about value changes.
  void notify(T value) {
    for (var i = 0; i < _listeners.length; i++) _listeners[i](value);
  }

  /// Listeners.
  final List<ValueChanged<T>> _listeners = <ValueChanged<T>>[];

  @override
  void addListener(ValueChanged<T> listener) => _listeners.add(listener);

  @override
  void removeListener(ValueChanged<T> listener) => _listeners.remove(listener);

  /// Close notifier.
  void close() => _listeners.clear();
}
