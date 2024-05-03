import 'package:meta/meta.dart';

import 'event.dart';

/// {@template spinify_channel_push}
/// Base class for all channel push events.
/// {@endtemplate}
/// {@category Event}
/// {@subCategory Push}
@immutable
abstract base class SpinifyChannelPush extends SpinifyEvent {
  /// {@macro spinify_channel_push}
  const SpinifyChannelPush({
    required super.timestamp,
    required this.channel,
  });

  /// Channel
  final String channel;

  @override
  @nonVirtual
  bool get isPush => true;

  @override
  String toString() => 'SpinifyChannelPush{channel: $channel}';
}
