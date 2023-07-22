import 'dart:async';

import 'package:centrifuge_dart/src/model/state.dart';
import 'package:meta/meta.dart';

/// Class responsible for sending and receiving data from the server.
/// {@nodoc}
@internal
abstract interface class ICentrifugeTransport {
  /// State of client.
  /// {@nodoc}
  CentrifugeState get state;

  /// Stream of client states.
  /// {@nodoc}
  abstract final Stream<CentrifugeState> states;

  /// Connect to the server.
  /// [url] is a URL of endpoint.
  /// [getToken] is a callback to get/refresh tokens.
  /// [getPayload] is a callback to get initial connection payload data.
  /// {@nodoc}
  Future<void> connect({
    required String url,
    required ({String name, String version}) client,
    FutureOr<String?> Function()? getToken,
    FutureOr<List<int>?> Function()? getPayload,
  });

  /// Disconnect from the server.
  /// {@nodoc}
  Future<void> disconnect();

  /// Permanent close connection to the server and
  /// free all allocated resources.
  /// {@nodoc}
  Future<void> close();
}
