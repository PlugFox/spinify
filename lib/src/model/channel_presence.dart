import 'package:meta/meta.dart';
import 'package:spinify/src/model/channel_push.dart';
import 'package:spinify/src/model/client_info.dart';

/// {@template channel_presence}
/// Channel presence.
/// Join / Leave events.
/// {@endtemplate}
/// {@category Entity}
/// {@subCategory Channel}
/// {@subCategory Presence}
@immutable
sealed class CentrifugeChannelPresence extends CentrifugeChannelPush {
  /// {@macro channel_presence}
  const CentrifugeChannelPresence({
    required super.timestamp,
    required super.channel,
    required this.info,
  });

  /// Client info
  final CentrifugeClientInfo info;

  /// Whether this is a join event
  abstract final bool isJoin;

  /// Whether this is a leave event
  abstract final bool isLeave;
}

/// {@macro channel_presence}
final class CentrifugeJoin extends CentrifugeChannelPresence {
  /// {@macro channel_presence}
  const CentrifugeJoin({
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
}

/// {@macro channel_presence}
final class CentrifugeLeave extends CentrifugeChannelPresence {
  /// {@macro channel_presence}
  const CentrifugeLeave({
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
}
