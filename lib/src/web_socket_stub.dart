import 'dart:async';

import 'package:meta/meta.dart';

import 'model/annotations.dart';
import 'model/exception.dart';
import 'model/transport_interface.dart';

/// Stub for WebSocket client.
@unsafe
@internal
@Throws([SpinifyTransportException])
Future<WebSocket> $webSocketConnect({
  required String url, // e.g. 'ws://localhost:8000/connection/websocket'
  Map<String, String>? headers, // e.g. {'Authorization': 'Bearer <token>'}
  Iterable<String>? protocols, // e.g. {'centrifuge-protobuf'}
  Map<String, Object?>? options, // Other options
}) =>
    throw const SpinifyTransportException(
      message: 'WebSocket is not supported at current platform',
    );
