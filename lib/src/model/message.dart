import 'package:centrifuge_dart/src/model/channel_push.dart';

/// {@template message}
/// Message push from Centrifugo server.
/// {@endtemplate}
final class CentrifugeMessage extends CentrifugeChannelPush {
  /// {@macro message}
  const CentrifugeMessage({
    required super.timestamp,
    required super.channel,
    required this.data,
  });

  @override
  String get type => 'message';

  /// Payload of message.
  final List<int> data;
}
