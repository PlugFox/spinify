import 'package:centrifuge_dart/src/model/channel_event.dart';
import 'package:centrifuge_dart/src/model/client_info.dart';
import 'package:meta/meta.dart';

/// {@template channel_presence_event}
/// Channel presence.
/// Join / Leave events.
/// {@endtemplate}
/// {@category Entity}
/// {@subCategory Channel}
/// {@subCategory Presence}
@immutable
sealed class CentrifugeChannelPresenceEvent extends CentrifugeChannelEvent {
  /// {@macro channel_presence_event}
  const CentrifugeChannelPresenceEvent({
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

/// {@macro channel_presence_event}
final class CentrifugeJoinEvent extends CentrifugeChannelPresenceEvent {
  /// {@macro channel_presence_event}
  const CentrifugeJoinEvent({
    required super.channel,
    required super.info,
  });

  @override
  bool get isJoin => true;

  @override
  bool get isLeave => false;
}

/// {@macro channel_presence_event}
final class CentrifugeLeaveEvent extends CentrifugeChannelPresenceEvent {
  /// {@macro channel_presence_event}
  const CentrifugeLeaveEvent({
    required super.channel,
    required super.info,
  });

  @override
  bool get isJoin => false;

  @override
  bool get isLeave => true;
}
