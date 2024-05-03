import 'channel_push.dart';

/// {@template refresh}
/// Refresh push from Centrifugo server.
/// {@endtemplate}
/// {@category Event}
/// {@subCategory Push}
final class SpinifyRefresh extends SpinifyChannelPush {
  /// {@macro refresh}
  const SpinifyRefresh({
    required super.timestamp,
    required super.channel,
    required this.expires,
    this.ttl,
  });

  @override
  String get type => 'refresh';

  /// Whether a server will expire connection at some point
  final bool expires;

  /// Time when connection will be expired
  final DateTime? ttl;

  @override
  String toString() => 'SpinifyRefresh{channel: $channel}';
}
