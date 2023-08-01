import 'package:centrifuge_dart/src/model/event.dart';

/// {@template centrifuge_channel_event}
/// Base class for all channel events.
/// {@endtemplate}
abstract base class CentrifugeChannelEvent extends CentrifugeEvent {
  /// {@template centrifuge_channel_event}
  const CentrifugeChannelEvent({
    required this.channel,
  });

  /// Channel
  final String channel;
}
