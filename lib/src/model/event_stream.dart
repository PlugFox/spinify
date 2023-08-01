import 'dart:async';

import 'package:centrifuge_dart/src/model/channel_presence.dart';
import 'package:centrifuge_dart/src/model/event.dart';
import 'package:centrifuge_dart/src/model/publication.dart';

/// Stream of received events.
/// {@category Entity}
/// {@subCategory Event}
/// {@subCategory Channel}
final class CentrifugeEventStream extends StreamView<CentrifugeEvent> {
  /// Stream of received events.
  CentrifugeEventStream(super.stream);

  /// Publications stream.
  late final Stream<CentrifugePublication> publications =
      whereType<CentrifugePublication>();

  /// Stream of presence (join & leave) events.
  late final Stream<CentrifugeChannelPresenceEvent> presenceEvents =
      whereType<CentrifugeChannelPresenceEvent>();

  /// Join events
  late final Stream<CentrifugeJoinEvent> joinEvents =
      whereType<CentrifugeJoinEvent>();

  /// Leave events
  late final Stream<CentrifugeLeaveEvent> leaveEvents =
      whereType<CentrifugeLeaveEvent>();

  /// Filtered stream of data of [CentrifugeEvent].
  Stream<T> whereType<T extends CentrifugeEvent>() =>
      transform<T>(StreamTransformer<CentrifugeEvent, T>.fromHandlers(
        handleData: (data, sink) => switch (data) {
          T valid => sink.add(valid),
          _ => null,
        },
      )).asBroadcastStream();
}
