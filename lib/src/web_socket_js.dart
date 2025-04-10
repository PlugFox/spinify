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
  Map<String, Object?>? options, // Other options
}) async {
  StreamSubscription<web.Event>? onOpen, onError;
  // ignore: close_sinks
  web.WebSocket? socket;
  try {
    final completer = Completer<WebSocket$JS>();
    var future = completer.future;
    future = switch (options?['timeout']) {
      Duration timeout => future.timeout(timeout),
      _ => future,
    };
    final s = socket = web.WebSocket(
      url,
      <String>{
        ...?protocols,
        if (options?['protocols'] case Iterable<String> values) ...values,
      }.map<js.JSString>((e) => e.toJS).toList(growable: false).toJS,
    )
      // Change binary type from "blob" to "arraybuffer"
      ..binaryType = switch (options?['binaryType']) {
        'blob' || 'Blob' || 'BLOB' => 'blob',
        'arraybuffer' || 'arrayBuffer' || 'ArrayBuffer' => 'arraybuffer',
        _ => 'arraybuffer',
      };

    // The socket API guarantees that only a single open event will be
    // emitted.
    onOpen = s.onOpen.take(1).listen(
      (event) {
        if (completer.isCompleted) return;
        completer.complete(WebSocket$JS(socket: s));
      },
      cancelOnError: false,
    );
    onError = s.onError.take(1).listen(
      (event) {
        if (completer.isCompleted) return;
        // Unfortunately, the underlying WebSocket API doesn't expose any
        // specific information about the error itself.
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

    if (completer.isCompleted) {
      // The connection was already established or failed.
    } else if (s.readyState == web.WebSocket.OPEN) {
      final client = WebSocket$JS(socket: s);
      try {
        if (options?['afterConnect']
            case void Function(WebSocket client) afterConnect) {
          afterConnect(client);
        }
      } on Object {/* ignore */}
      completer.complete(client);
    } else if (s.readyState == web.WebSocket.CLOSING ||
        s.readyState == web.WebSocket.CLOSED) {
      completer.completeError(
        const SpinifyTransportException(
          message: 'WebSocket connection already closed',
        ),
        StackTrace.current,
      );
    }

    return await future; // Return the WebSocket instance.
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
    final controller = StreamController<web.MessageEvent>(sync: true);

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
      if (socket.readyState != web.WebSocket.CLOSED) socket.close();
    }

    onMessage = _socket.onMessage.listen(
      controller.add,
      cancelOnError: false,
      onDone: onDone,
    );

    onClose = _socket.onClose.listen(
      (event) {
        _closeCode = event.code;
        _closeReason = event.reason;
        onDone();
      },
      cancelOnError: false,
      onDone: onDone,
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

  /// The number of bytes of data that have been queued but not yet transmitted
  /// to the network.
  //int? get bufferedAmount => _socket.bufferedAmount;

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
      case js.JSObject blob:
        return blob; // if (blob.isA<web.Blob>())
      default:
        throw ArgumentError.value(data, 'data', 'Invalid data type.');
    }
  }

  @internal
  Future<List<int>> read(web.MessageEvent message) async {
    final data = message.data;
    if (data == null) {
      return <int>[];
    } else if (data.typeofEquals('object') &&
        (data as js.JSObject).instanceOfString('ArrayBuffer')) {
      return (data as js.JSArrayBuffer).toDart.asUint8List();
    } else if (data.typeofEquals('string')) {
      return utf8.encode((data as js.JSString).toDart);
    }
    switch (data) {
      case List<int> bytes:
        return bytes;
      case String text:
        return utf8.encode(text);
      case ByteBuffer bb:
        return bb.asUint8List();
      case TypedData td:
        return Uint8List.view(
          td.buffer,
          td.offsetInBytes,
          td.lengthInBytes,
        );
      default:
        if (data.isA<web.Blob>()) {
          final arrayBuffer = await (data as web.Blob).arrayBuffer().toDart;
          return arrayBuffer.toDart.asUint8List();
        } else {
          assert(false, 'Unsupported data type: $data');
          throw ArgumentError.value(data, 'data', 'Invalid data type.');
        }
    }
  }
}
