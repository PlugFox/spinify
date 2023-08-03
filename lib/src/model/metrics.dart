import 'package:meta/meta.dart';
import 'package:spinify/src/client/state.dart';

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
    required this.transferredCount,
    required this.receivedCount,
    required this.lastUrl,
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

  /// The total number of messages sent.
  final BigInt transferredCount;

  /// The total number of messages received.
  final BigInt receivedCount;

  /// The last URL used to connect.
  final String? lastUrl;

  @override
  int compareTo(SpinifyMetrics other) => timestamp.compareTo(other.timestamp);

  /// Convert metrics to JSON.
  Map<String, Object?> toJson() => <String, Object?>{
        'timestamp': timestamp,
        'state': state.toJson(),
        'reconnects': <String, int>{
          'successful': reconnects.successful,
          'total': reconnects.total,
        },
        'transferredSize': transferredSize,
        'receivedSize': receivedSize,
        'transferredCount': transferredCount,
        'receivedCount': receivedCount,
        'lastUrl': lastUrl,
      };

  @override
  String toString() => 'SpinifyMetrics{}';
}
