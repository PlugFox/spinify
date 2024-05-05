import 'dart:async';

import 'package:meta/meta.dart';

import 'channel_push.dart';

/// Stream of received pushes from Centrifugo server for a channel.
/// {@category Event}
/// {@category Client}
/// {@category Subscription}
/// {@subCategory Push}
/// {@subCategory Channel}
@immutable
final class SpinifyPushesStream extends StreamView<SpinifyChannelEvent> {
  /// Stream of received events.
  const SpinifyPushesStream({
    required Stream<SpinifyChannelEvent> pushes,
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
  final Stream<SpinifyPresence> presenceEvents;

  /// Join events
  final Stream<SpinifyJoin> joinEvents;

  /// Leave events
  final Stream<SpinifyLeave> leaveEvents;

  /// Filtered stream of data of [SpinifyEvent].
  Stream<T> whereType<T extends SpinifyChannelEvent>() =>
      transform<T>(StreamTransformer<SpinifyChannelEvent, T>.fromHandlers(
        handleData: (data, sink) => switch (data) {
          T valid => sink.add(valid),
          _ => null,
        },
      )).asBroadcastStream();

  @override
  String toString() => 'SpinifyPushesStream{}';
}
