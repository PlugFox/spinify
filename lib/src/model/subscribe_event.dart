import 'package:centrifuge_dart/src/model/channel_push.dart';

/// {@macro subscribe_event}
final class CentrifugeSubscribeEvent extends CentrifugeChannelPush {
  /// {@macro subscribe_event}
  const CentrifugeSubscribeEvent({
    required super.channel,
  });

  @override
  String get type => 'subscribe';
}
