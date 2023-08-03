import 'package:meta/meta.dart';
import 'package:spinify/src/model/event.dart';

/// {@template centrifuge_channel_push}
/// Base class for all channel push events.
/// {@endtemplate}
abstract base class CentrifugeChannelPush extends CentrifugeEvent {
  /// {@template centrifuge_channel_push}
  const CentrifugeChannelPush({
    required super.timestamp,
    required this.channel,
  });

  /// Channel
  final String channel;

  @override
  @nonVirtual
  bool get isPush => true;
}
