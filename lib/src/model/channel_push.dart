import 'package:centrifuge_dart/src/model/event.dart';

/// {@template centrifuge_channel_event}
/// Base class for all channel events.
/// {@endtemplate}
abstract base class CentrifugeChannelPush extends CentrifugeEvent {
  /// {@template centrifuge_channel_event}
  const CentrifugeChannelPush({
    required super.timestamp,
    required this.channel,
  });

  /// Channel
  final String channel;
}
