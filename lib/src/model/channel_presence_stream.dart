import 'dart:async';

import 'package:centrifuge_dart/src/model/channel_presence.dart';

/// Stream of Centrifuge's presence event changes.
/// Join & Leave events.
/// {@category Entity}
/// {@subCategory Channel}
/// {@subCategory Presence}
final class CentrifugeChannelPresenceStream
    extends StreamView<CentrifugeChannelPresenceEvent> {
  /// Stream of Centrifuge's presence event changes.
  /// Join & Leave events.
  CentrifugeChannelPresenceStream(super.stream);

  /// Join events
  late final Stream<CentrifugeJoinEvent> joinEvents =
      whereType<CentrifugeJoinEvent>();

  /// Leave events
  late final Stream<CentrifugeLeaveEvent> leaveEvents =
      whereType<CentrifugeLeaveEvent>();

  /// Filtered stream of data of [CentrifugeChannelPresenceEvent].
  Stream<T> whereType<T extends CentrifugeChannelPresenceEvent>() =>
      transform<T>(
          StreamTransformer<CentrifugeChannelPresenceEvent, T>.fromHandlers(
        handleData: (data, sink) => switch (data) {
          T valid => sink.add(valid),
          _ => null,
        },
      )).asBroadcastStream();
}
