import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:meta/meta.dart';

import 'client_info.dart';
import 'stream_position.dart';

/// {@template spinify_channel_push}
/// Base class for all channel push events.
/// {@endtemplate}
/// {@category Reply}
/// {@subCategory Channel}
/// {@subCategory Push}
@immutable
sealed class SpinifyChannelEvent implements Comparable<SpinifyChannelEvent> {
  /// {@macro spinify_channel_push}
  const SpinifyChannelEvent({
    required this.timestamp,
    required this.channel,
  });

  /// Timestamp
  final DateTime timestamp;

  /// Channel
  final String channel;

  /// Push type.
  abstract final String type;

  @override
  int compareTo(SpinifyChannelEvent other) =>
      timestamp.compareTo(other.timestamp);

  @override
  String toString() => '$type{channel: $channel}';
}

/// {@template publication}
/// Publication context
/// {@endtemplate}
/// {@category Reply}
/// {@subCategory Channel}
/// {@subCategory Push}
final class SpinifyPublication extends SpinifyChannelEvent {
  /// {@macro publication}
  const SpinifyPublication({
    required super.timestamp,
    required super.channel,
    required this.data,
    required this.offset,
    required this.info,
    required this.tags,
  });

  @override
  String get type => 'Publication';

  /// Publication payload
  final List<int> data;

  /// Optional offset inside history stream, this is an incremental number
  final fixnum.Int64? offset;

  /// Optional information about client connection who published this
  /// (only exists if publication comes from client-side publish() API).
  final SpinifyClientInfo? info;

  /// Optional tags, this is a map with string keys and string values
  final Map<String, String>? tags;
}

/// {@template channel_presence}
/// Channel presence.
/// Join / Leave events.
/// {@endtemplate}
/// {@category Reply}
/// {@subCategory Channel}
/// {@subCategory Push}
/// {@subCategory Presence}
sealed class SpinifyPresence extends SpinifyChannelEvent {
  /// {@macro channel_presence}
  const SpinifyPresence({
    required super.timestamp,
    required super.channel,
    required this.info,
  });

  /// Join event
  /// {@macro channel_presence}
  const factory SpinifyPresence.join({
    required DateTime timestamp,
    required String channel,
    required SpinifyClientInfo info,
  }) = SpinifyJoin;

  /// Leave event
  /// {@macro channel_presence}
  const factory SpinifyPresence.leave({
    required DateTime timestamp,
    required String channel,
    required SpinifyClientInfo info,
  }) = SpinifyLeave;

  /// Client info
  final SpinifyClientInfo info;

  /// Whether this is a join event
  abstract final bool isJoin;

  /// Whether this is a leave event
  abstract final bool isLeave;
}

/// Join event
/// {@macro channel_presence}
/// {@category Reply}
/// {@subCategory Channel}
/// {@subCategory Push}
/// {@subCategory Presence}
final class SpinifyJoin extends SpinifyPresence {
  /// {@macro channel_presence}
  const SpinifyJoin({
    required super.timestamp,
    required super.channel,
    required super.info,
  });

  @override
  String get type => 'Join';

  @override
  bool get isJoin => true;

  @override
  bool get isLeave => false;
}

/// Leave event
/// {@macro channel_presence}
/// {@category Reply}
/// {@subCategory Channel}
/// {@subCategory Push}
/// {@subCategory Presence}
final class SpinifyLeave extends SpinifyPresence {
  /// {@macro channel_presence}
  const SpinifyLeave({
    required super.timestamp,
    required super.channel,
    required super.info,
  });

  @override
  String get type => 'Leave';

  @override
  bool get isJoin => false;

  @override
  bool get isLeave => true;
}

/// {@template unsubscribe}
/// Unsubscribe push from Centrifugo server.
/// {@endtemplate}
/// {@category Reply}
/// {@subCategory Channel}
/// {@subCategory Push}
final class SpinifyUnsubscribe extends SpinifyChannelEvent {
  /// {@macro unsubscribe}
  const SpinifyUnsubscribe({
    required super.timestamp,
    required super.channel,
    required this.code,
    required this.reason,
  });

  @override
  String get type => 'Unsubscribe';

  /// Code of unsubscribe.
  final int code;

  /// Reason of unsubscribe.
  final String reason;
}

/// {@template message}
/// Message push from Centrifugo server.
/// {@endtemplate}
/// {@category Reply}
/// {@subCategory Channel}
/// {@subCategory Push}
final class SpinifyMessage extends SpinifyChannelEvent {
  /// {@macro message}
  const SpinifyMessage({
    required super.timestamp,
    required super.channel,
    required this.data,
  });

  @override
  String get type => 'Message';

  /// Payload of message.
  final List<int> data;
}

/// {@template subscribe}
/// Subscribe push from Centrifugo server.
/// {@endtemplate}
/// {@category Reply}
/// {@subCategory Channel}
/// {@subCategory Push}
final class SpinifySubscribe extends SpinifyChannelEvent {
  /// {@macro subscribe}
  const SpinifySubscribe({
    required super.timestamp,
    required super.channel,
    required this.recoverable,
    required this.positioned,
    required this.since,
    required this.data,
  });

  @override
  String get type => 'Subscribe';

  /// Whether subscription is recoverable.
  final bool recoverable;

  /// Data attached to subscription.
  final SpinifyStreamPosition since;

  /// Whether subscription is positioned.
  final bool positioned;

  /// Data attached to subscription.
  final List<int> data;
}

/// {@template connect}
/// Connect push from Centrifugo server.
/// {@endtemplate}
/// {@category Reply}
/// {@subCategory Channel}
/// {@subCategory Push}
final class SpinifyConnect extends SpinifyChannelEvent {
  /// {@macro connect}
  const SpinifyConnect({
    required super.timestamp,
    required super.channel,
    required this.client,
    required this.version,
    required this.data,
    required this.expires,
    required this.ttl,
    required this.pingInterval,
    required this.sendPong,
    required this.session,
    required this.node,
  });

  @override
  String get type => 'Connect';

  /// Unique client connection ID server issued to this connection
  final String client;

  /// Server version
  final String version;

  /// Whether a server will expire connection at some point
  final bool? expires;

  /// Time when connection will be expired
  final DateTime? ttl;

  /// Client must periodically (once in 25 secs, configurable) send
  /// ping messages to server. If pong has not beed received in 5 secs
  /// (configurable) then client must disconnect from server
  /// and try to reconnect with backoff strategy.
  final Duration? pingInterval;

  /// Whether to send asynchronous message when pong received.
  final bool? sendPong;

  /// Session ID.
  final String? session;

  /// Server node ID.
  final String? node;

  /// Payload of connected push.
  final List<int> data;
}

/// {@template disconnect}
/// Disconnect push from Centrifugo server.
/// {@endtemplate}
/// {@category Reply}
/// {@subCategory Channel}
/// {@subCategory Push}
final class SpinifyDisconnect extends SpinifyChannelEvent {
  /// {@macro disconnect}
  const SpinifyDisconnect({
    required super.timestamp,
    required super.channel,
    required this.code,
    required this.reason,
    required this.reconnect,
  });

  @override
  String get type => 'Disconnect';

  /// Code of disconnect.
  final int code;

  /// Reason of disconnect.
  final String reason;

  /// Reconnect flag.
  final bool reconnect;
}

/// {@template refresh}
/// Refresh push from Centrifugo server.
/// {@endtemplate}
/// {@category Reply}
/// {@subCategory Channel}
/// {@subCategory Push}
final class SpinifyRefresh extends SpinifyChannelEvent {
  /// {@macro refresh}
  const SpinifyRefresh({
    required super.timestamp,
    required super.channel,
    required this.expires,
    required this.ttl,
  });

  @override
  String get type => 'Refresh';

  /// Whether a server will expire connection at some point
  final bool expires;

  /// Time when connection will be expired
  final DateTime? ttl;
}
