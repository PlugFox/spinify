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

  /*
  /// The total number of messages & size of bytes sent.
  final ({BigInt count, BigInt size}) transferred;

  /// The total number of messages & size of bytes received.
  final ({BigInt count, BigInt size}) received;

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

@internal
@immutable
final class SpinifyMetrics$Immutable extends SpinifyMetrics {
  const SpinifyMetrics$Immutable();

  @override
  DateTime get timestamp => throw UnimplementedError();

  @override
  DateTime get initializedAt => throw UnimplementedError();

  @override
  int get commandId => throw UnimplementedError();

  @override
  SpinifyState get state => throw UnimplementedError();

  @override
  int get connects => throw UnimplementedError();

  @override
  DateTime? get lastConnectAt => throw UnimplementedError();

  @override
  String? get reconnectUrl => throw UnimplementedError();

  @override
  int? get reconnectAttempts => throw UnimplementedError();

  @override
  DateTime? get nextReconnectAt => throw UnimplementedError();

  @override
  int get disconnects => throw UnimplementedError();

  @override
  DateTime? get lastDisconnectAt => throw UnimplementedError();
}

@internal
final class SpinifyMetrics$Mutable extends SpinifyMetrics {
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

  SpinifyMetrics$Immutable freeze() => const SpinifyMetrics$Immutable();
}
