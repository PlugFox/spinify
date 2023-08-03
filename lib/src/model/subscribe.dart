import 'package:spinify/src/model/channel_push.dart';
import 'package:spinify/src/model/stream_position.dart';

/// {@template subscribe}
/// Subscribe push from Centrifugo server.
/// {@endtemplate}
/// {@category Event}
/// {@subCategory Push}
final class SpinifySubscribe extends SpinifyChannelPush {
  /// {@macro subscribe}
  const SpinifySubscribe({
    required super.timestamp,
    required super.channel,
    required this.positioned,
    required this.recoverable,
    required this.data,
    required this.streamPosition,
  });

  @override
  String get type => 'subscribe';

  /// Whether subscription is positioned.
  final bool positioned;

  /// Whether subscription is recoverable.
  final bool recoverable;

  /// Data attached to subscription.
  final List<int> data;

  /// Stream position.
  final SpinifyStreamPosition? streamPosition;

  @override
  String toString() => 'SpinifySubscribe{channel: $channel}';
}
