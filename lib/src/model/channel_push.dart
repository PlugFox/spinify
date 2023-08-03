import 'package:meta/meta.dart';
import 'package:spinify/src/model/event.dart';

/// {@template spinify_channel_push}
/// Base class for all channel push events.
/// {@endtemplate}
abstract base class SpinifyChannelPush extends SpinifyEvent {
  /// {@template spinify_channel_push}
  const SpinifyChannelPush({
    required super.timestamp,
    required this.channel,
  });

  /// Channel
  final String channel;

  @override
  @nonVirtual
  bool get isPush => true;
}
