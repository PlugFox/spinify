import 'dart:async';

import 'annotations.dart';

/// WebSocket interface.
abstract interface class WebSocket implements Sink<List<int>> {
  /// Stream of incoming messages.
  abstract final Stream<List<int>> stream;

  /// Close code.
  /// May be `null` if connection still open.
  int? get closeCode;

  /// Close reason.
  /// May be `null` if connection still open.
  String? get closeReason;

  /// Is connection closed.
  /// Returns `true` if connection closed.
  /// After connection closed no more messages can be sent or received.
  bool get isClosed;

  /// Adds [data] to the sink.
  /// Must not be called after a call to [close].
  @unsafe
  @override
  void add(List<int> data);

  @safe
  @override
  void close([int? code, String? reason]);
}

/// Create a Spinify transport
/// (e.g. WebSocket or gRPC with JSON or Protocol Buffers).
typedef SpinifyTransportBuilder = Future<WebSocket> Function({
  required String url, // e.g. 'ws://localhost:8000/connection/websocket'
  Map<String, String>? headers, // e.g. {'Authorization': 'Bearer <token>'}
  Iterable<String>? protocols, // e.g. {'centrifuge-protobuf'}
});
