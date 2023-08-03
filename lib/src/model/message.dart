import 'package:spinify/src/model/channel_push.dart';

/// {@template message}
/// Message push from Centrifugo server.
/// {@endtemplate}
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
}
