// coverage:ignore-file

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop' as js;
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:web/web.dart' as web;

import 'model/annotations.dart';
import 'model/exception.dart';
import 'model/transport_interface.dart';

const _BlobCodec _codec = _BlobCodec();

/// Create web socket client for Browser and JS environment.
@unsafe
@internal
@Throws([SpinifyTransportException])
Future<WebSocket> $webSocketConnect({
  required String url, // e.g. 'ws://localhost:8000/connection/websocket'
  Map<String, String>? headers, // e.g. {'Authorization': 'Bearer <token>'}
  Iterable<String>? protocols, // e.g. {'centrifuge-protobuf'}
}) async {
  StreamSubscription<web.Event>? onOpen, onError;
  // ignore: close_sinks
  web.WebSocket? socket;
  try {
    final s = socket = web.WebSocket(
      url,
      <String>{...?protocols}
          .map<js.JSString>((e) => e.toJS)
          .toList(growable: false)
          .toJS,
    );
    final completer = Completer<WebSocket$JS>();
    onOpen = s.onOpen.listen(
      (event) {
        if (completer.isCompleted) return;
        completer.complete(WebSocket$JS(socket: s));
      },
      cancelOnError: false,
    );
    onError = s.onError.listen(
      (event) {
        if (completer.isCompleted) return;
        completer.completeError(
          SpinifyTransportException(
            message: 'WebSocket connection failed',
            error: event,
          ),
          StackTrace.current,
        );
      },
      cancelOnError: false,
    );
    return await completer.future;
  } on SpinifyTransportException {
    socket?.close(1002, 'Protocol error during connection setup');
    rethrow;
  } on Object catch (error, stackTrace) {
    socket?.close(1002, 'Protocol error during connection setup');
    Error.throwWithStackTrace(
      SpinifyTransportException(
        message: 'Failed to connect to $url',
        error: error,
      ),
      stackTrace,
    );
  } finally {
    onOpen?.cancel().ignore();
    onError?.cancel().ignore();
  }
}

@internal
class WebSocket$JS implements WebSocket {
  WebSocket$JS({required web.WebSocket socket}) : _socket = socket {
    final controller = StreamController<web.MessageEvent>();

    stream = controller.stream.asyncMap(_codec.read).transform<List<int>>(
          StreamTransformer<List<int>, List<int>>.fromHandlers(
            handleData: _dataHandler,
            handleError: _errorHandler,
            handleDone: _doneHandler,
          ),
        );

    StreamSubscription<web.Event>? onMessage, onClose;

    var done = false;
    void onDone([_]) {
      if (done) return; // Ignore multiple calls.
      done = true;
      controller.close().ignore();
      onMessage?.cancel().ignore();
      onClose?.cancel().ignore();
    }

    onMessage = _socket.onMessage.listen(
      controller.add,
      cancelOnError: false,
    );

    onClose = _socket.onClose.listen(
      (event) {
        _closeCode = event.code;
        _closeReason = event.reason;
        onDone();
      },
      cancelOnError: false,
    );
  }

  /// Handle incoming data.
  void _dataHandler(List<int> data, EventSink<List<int>> sink) {
    // coverage:ignore-start
    if (data.isEmpty) return;
    // coverage:ignore-end
    sink.add(data);
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
      case ArgumentError error:
        sink.addError(
          SpinifyTransportException(
            message: 'Invalid WebSocket message data type',
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

  final web.WebSocket _socket;

  @override
  int? get closeCode => _closeCode;
  int? _closeCode;

  @override
  String? get closeReason => _closeReason;
  String? _closeReason;

  @override
  bool get isClosed => _isClosed;
  bool _isClosed = false;

  @override
  late final Stream<List<int>> stream;

  @override
  void add(List<int> event) => _socket.send(_codec.write(event));

  @override
  Future<void> close([int? code, String? reason]) async {
    _closeCode ??= code;
    _closeReason ??= reason;
    // coverage:ignore-start
    try {
      if (_socket.readyState == 3)
        return;
      else if (code != null && reason != null)
        _socket.close(code, reason);
      else if (code != null)
        _socket.close(code);
      else
        _socket.close();
      //assert(_socket.readyState == 3, 'Socket is not closed');
    } on Object {/* ignore */}
    // coverage:ignore-end
  }
}

@immutable
final class _BlobCodec {
  const _BlobCodec();

  @internal
  js.JSAny write(Object data) {
    // return web.Blob([Uint8List.fromList(bytes).toJS].toJS);
    switch (data) {
      case List<int> bytes:
        return Uint8List.fromList(bytes).toJS;
      case String text:
        return Uint8List.fromList(utf8.encode(text)).toJS;
      case TypedData td:
        return Uint8List.view(
          td.buffer,
          td.offsetInBytes,
          td.lengthInBytes,
        ).toJS;
      case ByteBuffer bb:
        return bb.asUint8List().toJS;
      case web.Blob blob:
        return blob;
      default:
        throw ArgumentError.value(data, 'data', 'Invalid data type.');
    }
  }

  @internal
  Future<List<int>> read(js.JSAny? data) async {
    switch (data) {
      case List<int> bytes:
        return bytes;
      case String text:
        return utf8.encode(text);
      case web.Blob blob:
        final arrayBuffer = await blob.arrayBuffer().toDart;
        return arrayBuffer.toDart.asUint8List();
      case TypedData td:
        return Uint8List.view(
          td.buffer,
          td.offsetInBytes,
          td.lengthInBytes,
        );
      case ByteBuffer bb:
        return bb.asUint8List();
      default:
        assert(false, 'Unsupported data type: $data');
        throw ArgumentError.value(data, 'data', 'Invalid data type.');
    }
  }
}
