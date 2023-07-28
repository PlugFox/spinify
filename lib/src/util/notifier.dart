import 'package:meta/meta.dart';

/// Notify about value changes.
/// {@nodoc}
typedef ValueChanged<T> = void Function(T value);

/// Notify about value changes.
/// {@nodoc}
@internal
abstract interface class CentrifugeListenable<T> {
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
final class CentrifugeChangeNotifier<T> implements CentrifugeListenable<T> {
  /// Notify about value changes.
  /// {@nodoc}
  CentrifugeChangeNotifier();

  /// Notify about value changes.
  /// {@nodoc}
  void notify(T value) {
    for (var i = 0; i < _listeners.length; i++) _listeners[i](value);
  }

  /// Listeners.
  /// {@nodoc}
  final List<ValueChanged<T>> _listeners = <ValueChanged<T>>[];

  @override
  void addListener(ValueChanged<T> listener) => _listeners.add(listener);

  @override
  void removeListener(ValueChanged<T> listener) => _listeners.remove(listener);

  /// Close notifier.
  void close() => _listeners.clear();
}
