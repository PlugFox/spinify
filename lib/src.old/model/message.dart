import 'package:spinify/src.old/model/channel_push.dart';

/// {@template message}
/// Message push from Centrifugo server.
/// {@endtemplate}
/// {@category Event}
/// {@subCategory Push}
final class SpinifyMessage extends SpinifyChannelPush {
  /// {@macro message}
  const SpinifyMessage({
    required super.timestamp,
    required super.channel,
    required this.data,
  });

  @override
  String get type => 'message';

  /// Payload of message.
  final List<int> data;

  @override
  String toString() => 'SpinifyMessage{channel: $channel}';
}
