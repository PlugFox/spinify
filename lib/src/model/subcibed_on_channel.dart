import 'package:centrifuge_dart/src/model/publication.dart';
import 'package:centrifuge_dart/src/model/stream_position.dart';
import 'package:meta/meta.dart';

/// Subscribed on channel message.
@immutable
final class SubcibedOnChannel {
  /// Subscribed on channel message.
  const SubcibedOnChannel({
    required this.channel,
    required this.expires,
    required this.ttl,
    required this.recoverable,
    required this.since,
    required this.publications,
    required this.recovered,
    required this.positioned,
    required this.wasRecovering,
    required this.data,
  });

  /// Channel name.
  final String channel;

  /// Whether channel is expired.
  final bool expires;

  /// Time to live in seconds.
  final DateTime? ttl;

  /// Whether channel is recoverable.
  final bool recoverable;

  /// Stream position.
  final CentrifugeStreamPosition? since;

  /// List of publications since last stream position.
  final List<CentrifugePublication> publications;

  /// Whether channel is recovered after stream failure.
  final bool recovered;

  /// Whether channel is positioned at last stream position.
  final bool positioned;

  /// Whether channel is recovering after stream failure.
  final bool wasRecovering;

  /// Raw data.
  final List<int>? data;
}
