import 'package:meta/meta.dart';

/// {@template spinify_event}
/// Base class for all channel events.
/// {@endtemplate}
/// {@category Event}
@immutable
abstract base class SpinifyEvent implements Comparable<SpinifyEvent> {
  /// {@macro spinify_event}
  const SpinifyEvent({
    required this.timestamp,
  });

  /// Event type.
  abstract final String type;

  /// Timestamp of event
  final DateTime timestamp;

  /// Whether this event is a push event.
  bool get isPush;

  @override
  int compareTo(SpinifyEvent other) => timestamp.compareTo(other.timestamp);

  @override
  String toString() => 'SpinifyEvent{type: $type}';
}
