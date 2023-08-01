import 'dart:async';

import 'package:centrifuge_dart/src/model/channel_presence.dart';
import 'package:centrifuge_dart/src/model/channel_push.dart';
import 'package:centrifuge_dart/src/model/event.dart';
import 'package:centrifuge_dart/src/model/publication.dart';

/// Stream of received pushes from Centrifugo server for a channel.
/// {@category Entity}
/// {@subCategory Event}
/// {@subCategory Channel}
final class CentrifugePushesStream extends StreamView<CentrifugeChannelPush> {
  /// Stream of received events.
  CentrifugePushesStream({
    required Stream<CentrifugeChannelPush> pushes,
    required this.publications,
    required this.presenceEvents,
    required this.joinEvents,
    required this.leaveEvents,
  }) : super(pushes);

  /// Publications stream.
  final Stream<CentrifugePublication> publications;

  /// Stream of presence (join & leave) events.
  final Stream<CentrifugeChannelPresence> presenceEvents;

  /// Join events
  final Stream<CentrifugeJoin> joinEvents;

  /// Leave events
  final Stream<CentrifugeLeave> leaveEvents;

  /// Filtered stream of data of [CentrifugeEvent].
  Stream<T> whereType<T extends CentrifugeChannelPush>() =>
      transform<T>(StreamTransformer<CentrifugeChannelPush, T>.fromHandlers(
        handleData: (data, sink) => switch (data) {
          T valid => sink.add(valid),
          _ => null,
        },
      )).asBroadcastStream();
}
