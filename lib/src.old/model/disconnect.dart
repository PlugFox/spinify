import 'channel_push.dart';

/// {@template disconnect}
/// Disconnect push from Centrifugo server.
/// {@endtemplate}
/// {@category Event}
/// {@subCategory Push}
final class SpinifyDisconnect extends SpinifyChannelPush {
  /// {@macro disconnect}
  const SpinifyDisconnect({
    required super.timestamp,
    required super.channel,
    required this.code,
    required this.reason,
    required this.reconnect,
  });

  @override
  String get type => 'disconnect';

  /// Code of disconnect.
  final int code;

  /// Reason of disconnect.
  final String reason;

  /// Reconnect flag.
  final bool reconnect;

  @override
  String toString() => 'SpinifyDisconnect{channel: $channel}';
}
