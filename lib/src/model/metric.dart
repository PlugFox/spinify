import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:meta/meta.dart';

import 'state.dart';
import 'subscription_state.dart';

/*
/// Subscription count
/// - total
/// - unsubscribed
/// - subscribing
/// - subscribed
///
/// {@category Metrics}
/// {@category Entity}
typedef SpinifySubscriptionCount = ({
  int total,
  int unsubscribed,
  int subscribing,
  int subscribed
}); */

/// {@template metrics}
/// Metrics of Spinify client.
/// {@endtemplate}
///
/// {@category Metrics}
sealed class SpinifyMetrics implements Comparable<SpinifyMetrics> {
  /// {@macro metrics}
  const SpinifyMetrics();

  /// Timestamp of the metrics.
  abstract final DateTime timestamp;

  /// The time when the client was initialized.
  abstract final DateTime initializedAt;

  /// Next Command ID.
  /// Incremented after each command.
  abstract final int commandId;

  /// The current state of the client.
  abstract final SpinifyState state;

  /// The total number of bytes sent.
  abstract final fixnum.Int64 bytesSent;

  /// The total number of bytes received.
  abstract final fixnum.Int64 bytesReceived;

  /// The total number of messages sent.
  abstract final fixnum.Int64 messagesSent;

  /// The total number of messages received.
  abstract final fixnum.Int64 messagesReceived;

  /*
  /// The number of subscriptions.
  final ({
    SpinifySubscriptionCount client,
    SpinifySubscriptionCount server
  }) subscriptions;

  /// The average speed of the request/response in milliseconds.
  /// - min - minimum speed
  /// - avg - average speed
  /// - max - maximum speed
  final ({int min, int avg, int max}) speed;

  /// Is refresh active.
  final bool isRefreshActive;
  */

  /// The total number of successful connections.
  abstract final int connects;

  /// The time of the last connect.
  abstract final DateTime? lastConnectAt;

  /// Last connected URL.
  /// Used for reconnecting after connection lost.
  /// If null, then client is not connected or interractively disconnected.
  abstract final String? reconnectUrl;

  /// Number of reconnect attempts.
  /// If null, then client is not connected yet or interractively disconnected.
  abstract final int? reconnectAttempts;

  /// Next reconnect time in case of connection lost.
  abstract final DateTime? nextReconnectAt;

  /// The total number of times the connection has been disconnected.
  abstract final int disconnects;

  /// The time of the last disconnect.
  abstract final DateTime? lastDisconnectAt;

  /// The last received ping at.
  abstract final DateTime? lastPingAt;

  /// Pings count.
  abstract final fixnum.Int64 receivedPings;

  /// Metrics of all channels.
  abstract final Map<String, SpinifyMetrics$Channel> channels;

  /// Convert metrics to JSON.
  Map<String, Object?> toJson() => <String, Object?>{
        'timestamp': timestamp.toUtc().toIso8601String(),
        'initializedAt': initializedAt.toUtc().toIso8601String(),
        'commandId': commandId,
        'state': state,
        'bytesSent': bytesSent.toString(),
        'bytesReceived': bytesReceived.toString(),
        'messagesSent': messagesSent.toString(),
        'messagesReceived': messagesReceived.toString(),
        'connects': connects,
        'lastConnectAt': lastConnectAt?.toUtc().toIso8601String(),
        'reconnectUrl': reconnectUrl,
        'reconnectAttempts': reconnectAttempts,
        'nextReconnectAt': nextReconnectAt?.toUtc().toIso8601String(),
        'disconnects': disconnects,
        'lastDisconnectAt': lastDisconnectAt?.toUtc().toIso8601String(),
        'lastPingAt': lastPingAt?.toUtc().toIso8601String(),
        'receivedPings': receivedPings.toString(),
        'channels': <String, Object?>{
          for (final entry in channels.entries) entry.key: entry.value.toJson(),
        },
      };

  @override
  int compareTo(SpinifyMetrics other) => timestamp.compareTo(other.timestamp);

  @override
  String toString() => 'SpinifyMetrics{}';
}

/// {@template metrics_channel}
/// Metrics of Spinify channel.
/// {@endtemplate}
///
/// {@category Metrics}
sealed class SpinifyMetrics$Channel {
  /// {@macro metrics_channel}
  const SpinifyMetrics$Channel();

  /// The current state of the channel.
  abstract final SpinifySubscriptionState state;

  /// The total number of publications sent.
  abstract final fixnum.Int64 publicationsSent;

  /// The total number of publications received.
  abstract final fixnum.Int64 publicationsReceived;

  /// The total number of successful subscriptions.
  abstract final int subscribes;

  /// The time of the last subscribe.
  abstract final DateTime? lastSubscribeAt;

  /// Number of reconnect attempts.
  /// If null, then client is not connected yet or interractively resubscribed.
  abstract final int? resubscribeAttempts;

  /// Next reconnect time in case of connection lost.
  abstract final DateTime? nextResubscribeAt;

  /// The total number of times the connection has been unsubscribed.
  abstract final int unsubscribes;

  /// The time of the last unsubscribe.
  abstract final DateTime? lastUnsubscribeAt;

  /// The time of the next token refresh.
  abstract final DateTime? ttl;

  /// Convert channel metrics to JSON.
  Map<String, Object?> toJson() => <String, Object?>{
        'state': state,
        'publicationsSent': publicationsSent.toString(),
        'publicationsReceived': publicationsReceived.toString(),
        'subscribes': subscribes,
        'lastSubscribeAt': lastSubscribeAt?.toUtc().toIso8601String(),
        'resubscribeAttempts': resubscribeAttempts,
        'nextResubscribeAt': nextResubscribeAt?.toUtc().toIso8601String(),
        'unsubscribes': unsubscribes,
        'lastUnsubscribeAt': lastUnsubscribeAt?.toUtc().toIso8601String(),
        'ttl': ttl?.toUtc().toIso8601String(),
      };

  @override
  String toString() => r'SpinifyMetrics$Channel{}';
}

/// {@macro metrics}
@immutable
final class SpinifyMetrics$Immutable extends SpinifyMetrics {
  /// {@macro metrics}
  const SpinifyMetrics$Immutable({
    required this.timestamp,
    required this.initializedAt,
    required this.commandId,
    required this.state,
    required this.connects,
    required this.lastConnectAt,
    required this.reconnectUrl,
    required this.reconnectAttempts,
    required this.nextReconnectAt,
    required this.disconnects,
    required this.lastDisconnectAt,
    required this.bytesReceived,
    required this.bytesSent,
    required this.messagesReceived,
    required this.messagesSent,
    required this.lastPingAt,
    required this.receivedPings,
    required this.channels,
  });

  @override
  final DateTime timestamp;

  @override
  final DateTime initializedAt;

  @override
  final int commandId;

  @override
  final SpinifyState state;

  @override
  final int connects;

  @override
  final DateTime? lastConnectAt;

  @override
  final String? reconnectUrl;

  @override
  final int? reconnectAttempts;

  @override
  final DateTime? nextReconnectAt;

  @override
  final int disconnects;

  @override
  final DateTime? lastDisconnectAt;

  @override
  final fixnum.Int64 bytesReceived;

  @override
  final fixnum.Int64 bytesSent;

  @override
  final fixnum.Int64 messagesReceived;

  @override
  final fixnum.Int64 messagesSent;

  @override
  final DateTime? lastPingAt;

  @override
  final fixnum.Int64 receivedPings;

  @override
  final Map<String, SpinifyMetrics$Channel$Immutable> channels;
}

/// {@macro metrics_channel}
@immutable
final class SpinifyMetrics$Channel$Immutable extends SpinifyMetrics$Channel {
  /// {@macro metrics_channel}
  const SpinifyMetrics$Channel$Immutable({
    required this.state,
    required this.publicationsSent,
    required this.publicationsReceived,
    required this.subscribes,
    required this.lastSubscribeAt,
    required this.resubscribeAttempts,
    required this.nextResubscribeAt,
    required this.unsubscribes,
    required this.lastUnsubscribeAt,
    required this.ttl,
  });
  @override
  final SpinifySubscriptionState state;

  @override
  final fixnum.Int64 publicationsSent;

  @override
  final fixnum.Int64 publicationsReceived;

  @override
  final int subscribes;

  @override
  final DateTime? lastSubscribeAt;

  @override
  final int? resubscribeAttempts;

  @override
  final DateTime? nextResubscribeAt;

  @override
  final int unsubscribes;

  @override
  final DateTime? lastUnsubscribeAt;

  @override
  final DateTime? ttl;
}

/// {@macro metrics}
final class SpinifyMetrics$Mutable extends SpinifyMetrics {
  /// {@macro metrics}
  SpinifyMetrics$Mutable();

  @override
  DateTime get timestamp => DateTime.now();

  @override
  final DateTime initializedAt = DateTime.now();

  @override
  int commandId = 1;

  @override
  SpinifyState state = SpinifyState$Disconnected();

  @override
  int connects = 0;

  @override
  DateTime? lastConnectAt;

  @override
  String? reconnectUrl;

  @override
  int? reconnectAttempts;

  @override
  DateTime? nextReconnectAt;

  @override
  int disconnects = 0;

  @override
  DateTime? lastDisconnectAt;

  @override
  fixnum.Int64 bytesReceived = fixnum.Int64.ZERO;

  @override
  fixnum.Int64 bytesSent = fixnum.Int64.ZERO;

  @override
  fixnum.Int64 messagesReceived = fixnum.Int64.ZERO;

  @override
  fixnum.Int64 messagesSent = fixnum.Int64.ZERO;

  @override
  DateTime? lastPingAt;

  @override
  fixnum.Int64 receivedPings = fixnum.Int64.ZERO;

  @override
  final Map<String, SpinifyMetrics$Channel$Mutable> channels =
      <String, SpinifyMetrics$Channel$Mutable>{};

  /// Freezes the metrics.
  SpinifyMetrics$Immutable freeze() => SpinifyMetrics$Immutable(
        timestamp: timestamp,
        initializedAt: initializedAt,
        commandId: commandId,
        state: state,
        connects: connects,
        lastConnectAt: lastConnectAt,
        reconnectUrl: reconnectUrl,
        reconnectAttempts: reconnectAttempts,
        nextReconnectAt: nextReconnectAt,
        disconnects: disconnects,
        lastDisconnectAt: lastDisconnectAt,
        bytesReceived: bytesReceived,
        bytesSent: bytesSent,
        messagesReceived: messagesReceived,
        messagesSent: messagesSent,
        lastPingAt: lastPingAt,
        receivedPings: receivedPings,
        channels: Map<String, SpinifyMetrics$Channel$Immutable>.unmodifiable(
          <String, SpinifyMetrics$Channel$Immutable>{
            for (final entry in channels.entries)
              entry.key: entry.value.freeze(),
          },
        ),
      );
}

/// {@macro metrics_channel}
final class SpinifyMetrics$Channel$Mutable extends SpinifyMetrics$Channel {
  /// {@macro metrics_channel}
  SpinifyMetrics$Channel$Mutable();

  @override
  SpinifySubscriptionState state = SpinifySubscriptionState$Unsubscribed();

  @override
  fixnum.Int64 publicationsSent = fixnum.Int64.ZERO;

  @override
  fixnum.Int64 publicationsReceived = fixnum.Int64.ZERO;

  @override
  int subscribes = 0;

  @override
  DateTime? lastSubscribeAt;

  @override
  int? resubscribeAttempts;

  @override
  DateTime? nextResubscribeAt;

  @override
  int unsubscribes = 0;

  @override
  DateTime? lastUnsubscribeAt;

  @override
  DateTime? ttl;

  /// Freezes the channel metrics.
  SpinifyMetrics$Channel$Immutable freeze() => SpinifyMetrics$Channel$Immutable(
        state: state,
        publicationsSent: publicationsSent,
        publicationsReceived: publicationsReceived,
        subscribes: subscribes,
        lastSubscribeAt: lastSubscribeAt,
        resubscribeAttempts: resubscribeAttempts,
        nextResubscribeAt: nextResubscribeAt,
        unsubscribes: unsubscribes,
        lastUnsubscribeAt: lastUnsubscribeAt,
        ttl: ttl,
      );
}
