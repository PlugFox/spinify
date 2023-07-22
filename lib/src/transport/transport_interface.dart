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
  /// {@nodoc}
  Future<void> connect(String url);

  /// Disconnect from the server.
  /// e.g. code: 0, reason: 'disconnect called'
  /// {@nodoc}
  Future<void> disconnect(int code, String reason);

  /// Permanent close connection to the server and
  /// free all allocated resources.
  /// {@nodoc}
  Future<void> close();
}
