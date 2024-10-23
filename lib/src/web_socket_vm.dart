import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'model/annotations.dart';
import 'model/exception.dart';
import 'model/transport_interface.dart';

/// Create web socket client for Dart VM (dart:io) environment.
@unsafe
@internal
@Throws([SpinifyTransportException])
Future<WebSocket> $webSocketConnect({
  required String url, // e.g. 'ws://localhost:8000/connection/websocket'
  Map<String, String>? headers, // e.g. {'Authorization': 'Bearer <token>'}
  Iterable<String>? protocols, // e.g. {'centrifuge-protobuf'}
}) async {
  io.WebSocket? socket;
  try {
    // ignore: close_sinks
    final s = socket = await io.WebSocket.connect(
      url,
      headers: headers,
      protocols: protocols,
    );
    return WebSocket$VM(socket: s);
  } on SpinifyTransportException {
    socket?.close(1002, 'Protocol error during connection setup').ignore();
    rethrow;
  } on Object catch (error, stackTrace) {
    socket?.close(1002, 'Protocol error during connection setup').ignore();
    Error.throwWithStackTrace(
      SpinifyTransportException(
        message: 'Failed to connect to $url',
        error: error,
      ),
      stackTrace,
    );
  }
}

@internal
class WebSocket$VM implements WebSocket {
  WebSocket$VM({required io.WebSocket socket}) : _socket = socket {
    stream = _socket.transform<List<int>>(
      StreamTransformer<Object?, List<int>>.fromHandlers(
        handleData: _dataHandler,
        handleError: _errorHandler,
        handleDone: _doneHandler,
      ),
    );
  }

  /// Handle incoming data.
  void _dataHandler(Object? data, EventSink<List<int>> sink) {
    final List<int> bytes;
    // coverage:ignore-start
    switch (data) {
      case List<int> b:
        bytes = b;
      case TypedData td:
        bytes = Uint8List.view(
          td.buffer,
          td.offsetInBytes,
          td.lengthInBytes,
        );
      case ByteBuffer bb:
        bytes = bb.asUint8List();
      case String s:
        bytes = utf8.encode(s);
      default:
        sink.addError(
          SpinifyTransportException(
            message: 'Invalid WebSocket message',
            error: ArgumentError.value(data, 'data', 'Invalid message'),
            data: data,
          ),
        );
        return;
    }
    if (bytes.isEmpty) return;
    // coverage:ignore-end
    sink.add(bytes);
  }

  /// Handle incoming error.
  void _errorHandler(
    Object error,
    StackTrace stackTrace,
    EventSink<List<int>> sink,
  ) {
    // coverage:ignore-start
    switch (error) {
      case SpinifyTransportException error:
        sink.addError(error, stackTrace);
      case io.WebSocketException error:
        sink.addError(
          SpinifyTransportException(
            message: 'WebSocket error',
            error: error,
          ),
          stackTrace,
        );
      case io.SocketException error:
        sink.addError(
          SpinifyTransportException(
            message: 'Socket error',
            error: error,
          ),
          stackTrace,
        );
      case io.HandshakeException error:
        sink.addError(
          SpinifyTransportException(
            message: 'Handshake error',
            error: error,
          ),
          stackTrace,
        );
      case io.TlsException error:
        sink.addError(
          SpinifyTransportException(
            message: 'TLS error',
            error: error,
          ),
          stackTrace,
        );
      case io.HttpException error:
        sink.addError(
          SpinifyTransportException(
            message: 'HTTP error',
            error: error,
          ),
          stackTrace,
        );
      case Exception error:
        sink.addError(
          SpinifyTransportException(
            message: switch (error.toString()) {
              'Exception' => 'Unknown WebSocket exception',
              String message => message,
            },
            error: error,
          ),
          stackTrace,
        );
      default:
        sink.addError(
          SpinifyTransportException(
            message: 'Unknown WebSocket error',
            error: error,
          ),
          stackTrace,
        );
    }
    // coverage:ignore-end
  }

  /// Handle socket close.
  void _doneHandler(EventSink<List<int>> sink) {
    sink.close();
    _isClosed = true;
  }

  final io.WebSocket _socket;

  @override
  int? get closeCode => _socket.closeCode ?? _closeCode;
  int? _closeCode;

  @override
  String? get closeReason => _socket.closeReason ?? _closeReason;
  String? _closeReason;

  @override
  bool get isClosed => _isClosed;
  bool _isClosed = false;

  @override
  late final Stream<List<int>> stream;

  @override
  void add(List<int> event) => _socket.add(event);

  @override
  Future<void> close([int? code, String? reason]) async {
    _closeCode ??= code;
    _closeReason ??= reason;
    // coverage:ignore-start
    try {
      if (_socket.readyState == 3)
        return;
      else if (code != null && reason != null)
        _socket.close(code, reason).ignore();
      else if (code != null)
        _socket.close(code).ignore();
      else
        _socket.close().ignore();
      // Thats a bug in the dart:io, the socket is not closed immediately
      //assert(_socket.readyState == io.WebSocket.closed);
    } on Object {/* ignore */}
    // coverage:ignore-end
  }
}
