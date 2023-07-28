import 'dart:async';

import 'package:centrifuge_dart/src/client/state.dart';

/// Stream of Centrifuge's [CentrifugeState] changes.
/// {@category Client}
/// {@category Entity}
final class CentrifugeStatesStream extends StreamView<CentrifugeState> {
  /// Stream of Centrifuge's [CentrifugeState] changes.
  CentrifugeStatesStream(super.stream);

  /// Connection has not yet been established, but the WebSocket is trying.
  late final Stream<CentrifugeState$Disconnected> disconnected =
      whereType<CentrifugeState$Disconnected>();

  /// Disconnected state
  late final Stream<CentrifugeState$Connecting> connecting =
      whereType<CentrifugeState$Connecting>();

  /// Connected
  late final Stream<CentrifugeState$Connected> connected =
      whereType<CentrifugeState$Connected>();

  /// Permanently closed
  late final Stream<CentrifugeState$Closed> closed =
      whereType<CentrifugeState$Closed>();

  /// Filtered stream of data of [CentrifugeState].
  Stream<T> whereType<T extends CentrifugeState>() =>
      transform<T>(StreamTransformer<CentrifugeState, T>.fromHandlers(
        handleData: (data, sink) => switch (data) {
          T valid => sink.add(valid),
          _ => null,
        },
      )).asBroadcastStream();
}
