import 'package:meta/meta.dart';

import '../client/state.dart';

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
});

/// {@template metrics}
/// Metrics of Spinify client.
/// {@endtemplate}
///
/// {@category Metrics}
/// {@category Entity}
@immutable
final class SpinifyMetrics implements Comparable<SpinifyMetrics> {
  /// {@macro metrics}
  const SpinifyMetrics({
    required this.timestamp,
    required this.initializedAt,
    required this.state,
    required this.transferred,
    required this.received,
    required this.reconnects,
    required this.subscriptions,
    required this.speed,
    required this.lastUrl,
    required this.lastConnectTime,
    required this.lastDisconnectTime,
    required this.disconnects,
    required this.lastDisconnect,
    required this.isRefreshActive,
  });

  /// Timestamp of the metrics.
  final DateTime timestamp;

  /// The time when the client was initialized.
  final DateTime initializedAt;

  /// The current state of the client.
  final SpinifyState state;

  /// The total number of messages & size of bytes sent.
  final ({BigInt count, BigInt size}) transferred;

  /// The total number of messages & size of bytes received.
  final ({BigInt count, BigInt size}) received;

  /// The total number of times the connection has been re-established.
  final ({int successful, int total}) reconnects;

  /// The number of subscriptions.
  final ({
    SpinifySubscriptionCount client,
    SpinifySubscriptionCount server
  }) subscriptions;

  /// The speed of the request/response in milliseconds.
  /// - min - minimum speed
  /// - avg - average speed
  /// - max - maximum speed
  final ({int min, int avg, int max}) speed;

  /// The last URL used to connect.
  final String? lastUrl;

  /// The time of the last connect.
  final DateTime? lastConnectTime;

  /// The time of the last disconnect.
  final DateTime? lastDisconnectTime;

  /// The total number of times the connection has been disconnected.
  final int disconnects;

  /// The last disconnect reason.
  final ({int? code, String? reason})? lastDisconnect;

  /// Is refresh active.
  final bool isRefreshActive;

  @override
  int compareTo(SpinifyMetrics other) => timestamp.compareTo(other.timestamp);

  /// Convert metrics to JSON.
  Map<String, Object?> toJson() => <String, Object?>{
        'timestamp': timestamp.toIso8601String(),
        'initializedAt': initializedAt.toIso8601String(),
        'lastConnectTime': lastConnectTime?.toIso8601String(),
        'lastDisconnectTime': lastDisconnectTime?.toIso8601String(),
        'state': state.toJson(),
        'lastUrl': lastUrl,
        'reconnects': <String, int>{
          'successful': reconnects.successful,
          'total': reconnects.total,
        },
        'subscriptions': <String, Map<String, int>>{
          'client': <String, int>{
            'total': subscriptions.client.total,
            'unsubscribed': subscriptions.client.unsubscribed,
            'subscribing': subscriptions.client.subscribing,
            'subscribed': subscriptions.client.subscribed,
          },
          'server': <String, int>{
            'total': subscriptions.server.total,
            'unsubscribed': subscriptions.server.unsubscribed,
            'subscribing': subscriptions.server.subscribing,
            'subscribed': subscriptions.server.subscribed,
          },
        },
        'speed': <String, int>{
          'min': speed.min,
          'avg': speed.avg,
          'max': speed.max,
        },
        'transferred': <String, BigInt>{
          'count': transferred.count,
          'size': transferred.size,
        },
        'received': <String, BigInt>{
          'count': received.count,
          'size': received.size,
        },
        'isRefreshActive': isRefreshActive,
        'disconnects': disconnects,
        'lastDisconnect': switch (lastDisconnect) {
          (:int? code, :String? reason) => <String, Object?>{
              'code': code,
              'reason': reason,
            },
          _ => null,
        },
      };

  @override
  String toString() => 'SpinifyMetrics{}';
}
