import 'dart:async';

import 'package:meta/meta.dart';
import 'package:spinify/src/model/channel_presence.dart';
import 'package:spinify/src/model/channel_push.dart';
import 'package:spinify/src/model/event.dart';
import 'package:spinify/src/model/message.dart';
import 'package:spinify/src/model/publication.dart';

/// Stream of received pushes from Centrifugo server for a channel.
/// {@category Event}
/// {@category Client}
/// {@category Subscription}
/// {@subCategory Push}
/// {@subCategory Channel}
@immutable
final class SpinifyPushesStream extends StreamView<SpinifyChannelPush> {
  /// Stream of received events.
  const SpinifyPushesStream({
    required Stream<SpinifyChannelPush> pushes,
    required this.publications,
    required this.messages,
    required this.presenceEvents,
    required this.joinEvents,
    required this.leaveEvents,
  }) : super(pushes);

  /// Publications stream.
  final Stream<SpinifyPublication> publications;

  /// Messages stream.
  final Stream<SpinifyMessage> messages;

  /// Stream of presence (join & leave) events.
  final Stream<SpinifyChannelPresence> presenceEvents;

  /// Join events
  final Stream<SpinifyJoin> joinEvents;

  /// Leave events
  final Stream<SpinifyLeave> leaveEvents;

  /// Filtered stream of data of [SpinifyEvent].
  Stream<T> whereType<T extends SpinifyChannelPush>() =>
      transform<T>(StreamTransformer<SpinifyChannelPush, T>.fromHandlers(
        handleData: (data, sink) => switch (data) {
          T valid => sink.add(valid),
          _ => null,
        },
      )).asBroadcastStream();

  @override
  String toString() => 'SpinifyPushesStream{}';
}
