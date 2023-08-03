import 'package:meta/meta.dart';

/// {@template spinify_event}
/// Base class for all channel events.
/// {@endtemplate}
@immutable
abstract base class SpinifyEvent {
  /// {@template spinify_event}
  const SpinifyEvent({
    required this.timestamp,
  });

  /// Event type.
  abstract final String type;

  /// Timestamp of event
  final DateTime timestamp;

  /// Whether this event is a push event.
  bool get isPush;
}
