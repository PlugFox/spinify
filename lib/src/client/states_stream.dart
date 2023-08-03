import 'dart:async';

import 'package:spinify/src/client/state.dart';

/// Stream of Spinify's [SpinifyState] changes.
/// {@category Client}
/// {@category Entity}
final class SpinifyStatesStream extends StreamView<SpinifyState> {
  /// Stream of Spinify's [SpinifyState] changes.
  SpinifyStatesStream(super.stream);

  /// Connection has not yet been established, but the WebSocket is trying.
  late final Stream<SpinifyState$Disconnected> disconnected =
      whereType<SpinifyState$Disconnected>();

  /// Disconnected state
  late final Stream<SpinifyState$Connecting> connecting =
      whereType<SpinifyState$Connecting>();

  /// Connected
  late final Stream<SpinifyState$Connected> connected =
      whereType<SpinifyState$Connected>();

  /// Permanently closed
  late final Stream<SpinifyState$Closed> closed =
      whereType<SpinifyState$Closed>();

  /// Filtered stream of data of [SpinifyState].
  Stream<T> whereType<T extends SpinifyState>() =>
      transform<T>(StreamTransformer<SpinifyState, T>.fromHandlers(
        handleData: (data, sink) => switch (data) {
          T valid => sink.add(valid),
          _ => null,
        },
      )).asBroadcastStream();
}
