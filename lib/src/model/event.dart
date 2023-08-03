import 'package:meta/meta.dart';

/// {@template centrifuge_event}
/// Base class for all channel events.
/// {@endtemplate}
@immutable
abstract base class CentrifugeEvent {
  /// {@template centrifuge_event}
  const CentrifugeEvent({
    required this.timestamp,
  });

  /// Event type.
  abstract final String type;

  /// Timestamp of event
  final DateTime timestamp;

  /// Whether this event is a push event.
  bool get isPush;
}
