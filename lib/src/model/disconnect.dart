import 'package:spinify/src/model/channel_push.dart';

/// {@template disconnect}
/// Disconnect push from Centrifugo server.
/// {@endtemplate}
final class CentrifugeDisconnect extends CentrifugeChannelPush {
  /// {@macro disconnect}
  const CentrifugeDisconnect({
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
}
