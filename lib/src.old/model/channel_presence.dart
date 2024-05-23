import 'package:meta/meta.dart';
import 'channel_push.dart';
import 'client_info.dart';

/// {@template channel_presence}
/// Channel presence.
/// Join / Leave events.
/// {@endtemplate}
/// {@category Event}
/// {@subCategory Push}
@immutable
sealed class SpinifyChannelPresence extends SpinifyChannelPush {
  /// {@macro channel_presence}
  const SpinifyChannelPresence({
    required super.timestamp,
    required super.channel,
    required this.info,
  });

  /// Client info
  final SpinifyClientInfo info;

  /// Whether this is a join event
  abstract final bool isJoin;

  /// Whether this is a leave event
  abstract final bool isLeave;
}

/// {@macro channel_presence}
/// {@category Event}
/// {@subCategory Push}
/// {@subCategory Presence}
final class SpinifyJoin extends SpinifyChannelPresence {
  /// {@macro channel_presence}
  const SpinifyJoin({
    required super.timestamp,
    required super.channel,
    required super.info,
  });

  @override
  String get type => 'join';

  @override
  bool get isJoin => true;

  @override
  bool get isLeave => false;

  @override
  String toString() => 'SpinifyJoin{channel: $channel}';
}

/// {@macro channel_presence}
/// {@category Event}
/// {@subCategory Push}
/// {@subCategory Presence}
final class SpinifyLeave extends SpinifyChannelPresence {
  /// {@macro channel_presence}
  const SpinifyLeave({
    required super.timestamp,
    required super.channel,
    required super.info,
  });

  @override
  String get type => 'leave';

  @override
  bool get isJoin => false;

  @override
  bool get isLeave => true;

  @override
  String toString() => 'SpinifyLeave{channel: $channel}';
}
