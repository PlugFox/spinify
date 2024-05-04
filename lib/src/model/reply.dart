import 'package:meta/meta.dart';

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
    required this.ping,
    required this.pong,
    required this.session,
    required this.node,
  });

  @override
  String get type => 'ConnectResult';

  /// Client
  final String? client;

  /// Version
  final String? version;

  /// Expires
  final bool? expires;

  /// TTL
  final int? ttl;

  /// Data
  final List<int>? data;

  /// Subs
  final Map<String, SpinifySubscribeResult>? subs;

  /// Ping
  final int? ping;

  /// Pong
  final bool? pong;

  /// Session
  final String? session;

  /// Node
  final String? node;
}

/// {@macro reply}
final class SpinifySubscribeResult extends SpinifyReply {
  /// {@macro reply}
  const SpinifySubscribeResult({
    required super.id,
    required super.timestamp,
  });

  @override
  String get type => 'SubscribeResult';
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
  });

  @override
  String get type => 'PresenceResult';
}

/// {@macro reply}
final class SpinifyPresenceStatsResult extends SpinifyReply {
  /// {@macro reply}
  const SpinifyPresenceStatsResult({
    required super.id,
    required super.timestamp,
  });

  @override
  String get type => 'PresenceStatsResult';
}

/// {@macro reply}
final class SpinifyHistoryResult extends SpinifyReply {
  /// {@macro reply}
  const SpinifyHistoryResult({
    required super.id,
    required super.timestamp,
  });

  @override
  String get type => 'HistoryResult';
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
  });

  @override
  String get type => 'RPCResult';
}

/// {@macro reply}
final class SpinifyRefreshResult extends SpinifyReply {
  /// {@macro reply}
  const SpinifyRefreshResult({
    required super.id,
    required super.timestamp,
  });

  @override
  String get type => 'RefreshResult';
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
  });

  @override
  String get type => 'Error';
}
