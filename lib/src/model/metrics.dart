import 'package:meta/meta.dart';
import 'package:spinify/src/client/state.dart';

/// Subscription count
/// - total
/// - unsubscribed
/// - subscribing
/// - subscribed
typedef SpinifySubscriptionCount = ({
  int total,
  int unsubscribed,
  int subscribing,
  int subscribed
});

/// {@template metrics}
/// Metrics of Spinify client.
/// {@endtemplate}
/// {@category Client}
/// {@category Entity}
@immutable
final class SpinifyMetrics implements Comparable<SpinifyMetrics> {
  /// {@macro metrics}
  const SpinifyMetrics({
    required this.timestamp,
    required this.state,
    required this.transferredSize,
    required this.receivedSize,
    required this.reconnects,
    required this.subscriptions,
    required this.speed,
    required this.transferredCount,
    required this.receivedCount,
    required this.lastUrl,
    required this.lastConnectTime,
    required this.lastDisconnectTime,
    required this.disconnects,
    required this.lastDisconnect,
    required this.isRefreshActive,
  });

  /// Timestamp of the metrics.
  final DateTime timestamp;

  /// The current state of the client.
  final SpinifyState state;

  /// The total number of bytes sent.
  final BigInt transferredSize;

  /// The total number of bytes received.
  final BigInt receivedSize;

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

  /// The total number of messages sent.
  final BigInt transferredCount;

  /// The total number of messages received.
  final BigInt receivedCount;

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
        'state': state.toJson(),
        'reconnects': <String, int>{
          'successful': reconnects.successful,
          'total': reconnects.total,
        },
        'subscriptions': <String, Map<String, int>>{
          'client': {
            'total': subscriptions.client.total,
            'unsubscribed': subscriptions.client.unsubscribed,
            'subscribing': subscriptions.client.subscribing,
            'subscribed': subscriptions.client.subscribed,
          },
          'server': {
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
        'transferredSize': transferredSize,
        'receivedSize': receivedSize,
        'transferredCount': transferredCount,
        'receivedCount': receivedCount,
        'lastUrl': lastUrl,
        'lastConnectTime': lastConnectTime?.toIso8601String(),
        'lastDisconnectTime': lastDisconnectTime?.toIso8601String(),
        'disconnects': disconnects,
        'lastDisconnect': switch (lastDisconnect) {
          (:int? code, :String? reason) => <String, Object?>{
              'code': code,
              'reason': reason,
            },
          _ => null,
        },
        'isRefreshActive': isRefreshActive,
      };

  @override
  String toString() => 'SpinifyMetrics{}';
}
