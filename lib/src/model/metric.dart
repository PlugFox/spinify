import 'package:meta/meta.dart';

import 'state.dart';

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
  abstract final BigInt bytesSent;

  /// The total number of bytes received.
  abstract final BigInt bytesReceived;

  /// The total number of messages sent.
  abstract final BigInt messagesSent;

  /// The total number of messages received.
  abstract final BigInt messagesReceived;

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

  /// Convert metrics to JSON.
  Map<String, Object?> toJson() => <String, Object?>{};

  @override
  int compareTo(SpinifyMetrics other) => timestamp.compareTo(other.timestamp);

  @override
  String toString() => 'SpinifyMetrics{}';
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
  final BigInt bytesReceived;

  @override
  final BigInt bytesSent;

  @override
  final BigInt messagesReceived;

  @override
  final BigInt messagesSent;
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
  BigInt bytesReceived = BigInt.zero;

  @override
  BigInt bytesSent = BigInt.zero;

  @override
  BigInt messagesReceived = BigInt.zero;

  @override
  BigInt messagesSent = BigInt.zero;

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
      );
}
