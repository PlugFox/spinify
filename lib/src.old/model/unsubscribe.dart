import 'package:spinify/src.old/model/channel_push.dart';

/// {@template unsubscribe}
/// Unsubscribe push from Centrifugo server.
/// {@endtemplate}
/// {@category Event}
/// {@subCategory Push}
final class SpinifyUnsubscribe extends SpinifyChannelPush {
  /// {@macro unsubscribe}
  const SpinifyUnsubscribe({
    required super.timestamp,
    required super.channel,
    required this.code,
    required this.reason,
  });

  @override
  String get type => 'unsubscribe';

  /// Code of unsubscribe.
  final int code;

  /// Reason of unsubscribe.
  final String reason;

  @override
  String toString() => 'SpinifyUnsubscribe{channel: $channel}';
}
