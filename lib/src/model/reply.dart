import 'package:meta/meta.dart';

import 'channel_push.dart';
import 'client_info.dart';
import 'stream_position.dart';

/// {@template reply}
/// Reply sent from a server to a client.
///
/// Server will
/// only take the first non-null request out of these and may return an error
/// if client passed more than one request.
/// {@category Reply}
/// {@endtemplate}
@immutable
sealed class SpinifyReply implements Comparable<SpinifyReply> {
  /// {@macro reply}
  const SpinifyReply({
    required this.id,
    required this.timestamp,
  });

  /// Id will only be set to a value > 0 for replies to commands.
  /// For pushes it will have zero value.
  final int id;

  /// Timestamp of reply.
  final DateTime timestamp;

  /// Reply type.
  abstract final String type;

  @override
  int compareTo(SpinifyReply other) =>
      switch (timestamp.compareTo(other.timestamp)) {
        0 => id.compareTo(other.id),
        int result => result,
      };

  @override
  int get hashCode => id ^ type.hashCode ^ timestamp.microsecondsSinceEpoch;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpinifyReply &&
          id == other.id &&
          type == other.type &&
          timestamp == other.timestamp;

  @override
  String toString() => '$type{id: $id}';
}

/// Server ping message. Server will send this message to client periodically
/// to check if client is still connected.
///
/// Client must respond with async `SpinifyPingRequest{id: 0}` command message.
/// {@macro reply}
final class SpinifyServerPing extends SpinifyReply {
  /// {@macro reply}
  const SpinifyServerPing({
    required super.timestamp,
  }) : super(id: 0);

  @override
  String get type => 'ServerPing';
}

/// Push can be sent to a client as part of Reply in case of bidirectional
/// transport or without additional wrapping in case of unidirectional
/// transports. ProtocolVersion2 uses channel and one of the possible concrete
/// push messages.
///
/// {@macro reply}
final class SpinifyPush extends SpinifyReply {
  /// {@macro reply}
  const SpinifyPush({
    required super.timestamp,
    required this.event,
  }) : super(id: 0);

  @override
  String get type => 'Push';

  /// Channel push event
  String get channel => event.channel;

  /// Channel push event
  final SpinifyChannelEvent event;
}

/// {@macro reply}
final class SpinifyConnectResult extends SpinifyReply {
  /// {@macro reply}
  const SpinifyConnectResult({
    required super.id,
    required super.timestamp,
    required this.client,
    required this.version,
    required this.expires,
    required this.ttl,
    required this.data,
    required this.subs,
    required this.pingInterval,
    required this.sendPong,
    required this.session,
    required this.node,
  });

  @override
  String get type => 'ConnectResult';

  /// Unique client connection ID server issued to this connection
  final String client;

  /// Server version
  final String version;

  /// Expires
  final bool expires;

  /// TTL (Time to live)
  final DateTime? ttl;

  /// Payload
  final List<int>? data;

  /// Subs
  final Map<String, SpinifySubscribeResult>? subs;

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
}

/// {@macro reply}
final class SpinifySubscribeResult extends SpinifyReply {
  /// {@macro reply}
  const SpinifySubscribeResult({
    required super.id,
    required super.timestamp,
    required this.expires,
    required this.ttl,
    required this.recoverable,
    required this.publications,
    required this.recovered,
    required this.since,
    required this.positioned,
    required this.data,
    required this.wasRecovering,
  });

  @override
  String get type => 'SubscribeResult';

  /*
    bool expires = 1;
    uint32 ttl = 2;
    bool recoverable = 3;
    reserved 4, 5;
    string epoch = 6;
    repeated Publication publications = 7;
    bool recovered = 8;
    uint64 offset = 9;
    bool positioned = 10;
    bytes data = 11;
    bool was_recovering = 12;
  */

  /// Expires
  final bool expires;

  /// TTL
  final DateTime? ttl;

  /// Recoverable
  final bool recoverable;

  /// Publications
  final List<SpinifyPublication> publications;

  /// Recovered
  final bool recovered;

  /// Stream position
  final SpinifyStreamPosition since;

  /// Positioned
  final bool positioned;

  /// Data
  final List<int>? data;

  /// Was recovering
  final bool wasRecovering;
}

/// {@macro reply}
final class SpinifyUnsubscribeResult extends SpinifyReply {
  /// {@macro reply}
  const SpinifyUnsubscribeResult({
    required super.id,
    required super.timestamp,
  });

  @override
  String get type => 'UnsubscribeResult';
}

/// {@macro reply}
final class SpinifyPublishResult extends SpinifyReply {
  /// {@macro reply}
  const SpinifyPublishResult({
    required super.id,
    required super.timestamp,
  });

  @override
  String get type => 'PublishResult';
}

/// {@macro reply}
final class SpinifyPresenceResult extends SpinifyReply {
  /// {@macro reply}
  const SpinifyPresenceResult({
    required super.id,
    required super.timestamp,
    required this.presence,
  });

  @override
  String get type => 'PresenceResult';

  /// Presence
  /// { Channel : ClientInfo }
  final Map<String, SpinifyClientInfo> presence;
}

/// {@macro reply}
final class SpinifyPresenceStatsResult extends SpinifyReply {
  /// {@macro reply}
  const SpinifyPresenceStatsResult({
    required super.id,
    required super.timestamp,
    required this.numClients,
    required this.numUsers,
  });

  @override
  String get type => 'PresenceStatsResult';

  /// Number of clients
  final int numClients;

  /// Number of users
  final int numUsers;
}

/// {@macro reply}
final class SpinifyHistoryResult extends SpinifyReply {
  /// {@macro reply}
  const SpinifyHistoryResult({
    required super.id,
    required super.timestamp,
    required this.since,
  });

  @override
  String get type => 'HistoryResult';

  /// Offset
  final SpinifyStreamPosition since;
}

/// {@macro reply}
final class SpinifyPingResult extends SpinifyReply {
  /// {@macro reply}
  const SpinifyPingResult({
    required super.id,
    required super.timestamp,
  });

  @override
  String get type => 'PingResult';
}

/// {@macro reply}
final class SpinifyRPCResult extends SpinifyReply {
  /// {@macro reply}
  const SpinifyRPCResult({
    required super.id,
    required super.timestamp,
    required this.data,
  });

  @override
  String get type => 'RPCResult';

  /// Payload
  final List<int> data;
}

/// {@macro reply}
final class SpinifyRefreshResult extends SpinifyReply {
  /// {@macro reply}
  const SpinifyRefreshResult({
    required super.id,
    required super.timestamp,
    required this.client,
    required this.version,
    required this.expires,
    required this.ttl,
  });

  @override
  String get type => 'RefreshResult';

  /// Unique client connection ID server issued to this connection
  final String client;

  /// Server version
  final String version;

  /// Expires
  final bool expires;

  /// TTL
  final DateTime? ttl;
}

/// {@macro reply}
final class SpinifySubRefreshResult extends SpinifyReply {
  /// {@macro reply}
  const SpinifySubRefreshResult({
    required super.id,
    required super.timestamp,
  });

  @override
  String get type => 'SubRefreshResult';
}

/// Error can only be set in replies to commands. For pushes it will have zero
/// value.
///
/// {@macro reply}
final class SpinifyError extends SpinifyReply {
  /// {@macro reply}
  const SpinifyError({
    required super.id,
    required super.timestamp,
    required this.code,
    required this.message,
    required this.temporary,
  });

  @override
  String get type => 'Error';

  /// Error code.
  final int code;

  /// Error message.
  final String message;

  /// Is error temporary.
  final bool temporary;
}
