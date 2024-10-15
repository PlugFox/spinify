// coverage:ignore-file

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop' as js;
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:protobuf/protobuf.dart' as pb;
import 'package:web/web.dart' as web;

import 'model/channel_event.dart';
import 'model/command.dart';
import 'model/config.dart';
import 'model/metric.dart';
import 'model/reply.dart';
import 'model/transport_interface.dart';
import 'protobuf/client.pb.dart' as pb;
import 'protobuf/protobuf_codec.dart';
import 'util/event_queue.dart';

const _BlobCodec _blobCodec = _BlobCodec();

@immutable
final class _BlobCodec {
  const _BlobCodec();

  @internal
  web.Blob write(Object data) {
    switch (data) {
      case String text:
        return web.Blob([Uint8List.fromList(utf8.encode(text)).toJS].toJS);
      case TypedData td:
        return web.Blob([
          Uint8List.view(
            td.buffer,
            td.offsetInBytes,
            td.lengthInBytes,
          ).toJS
        ].toJS);
      case ByteBuffer bb:
        return web.Blob([bb.asUint8List().toJS].toJS);
      case List<int> bytes:
        return web.Blob([Uint8List.fromList(bytes).toJS].toJS);
      case web.Blob blob:
        return web.Blob([blob].toJS);
      default:
        throw ArgumentError.value(data, 'data', 'Invalid data type.');
    }
  }

  @internal
  Future<Uint8List> read(js.JSAny? data) async {
    switch (data) {
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
      case List<int> bytes:
        return Uint8List.fromList(bytes);
      default:
        assert(false, 'Unsupported data type: $data');
        throw ArgumentError.value(data, 'data', 'Invalid data type.');
    }
  }
}

/// Create a WebSocket Protocol Buffers transport.
@internal
Future<ISpinifyTransport> $create$WS$PB$Transport({
  /// URL for the connection
  required String url,

  /// Spinify client configuration
  required SpinifyConfig config,

  /// Metrics
  required SpinifyMetrics$Mutable metrics,

  /// Callback for reply messages
  required void Function(SpinifyReply reply) onReply,

  /// Callback for disconnect event
  required void Function({required bool temporary}) onDisconnect,
}) async {
  // ignore: close_sinks
  final socket = web.WebSocket(
    url,
    <String>{'centrifuge-protobuf'}
        .map((e) => e.toJS)
        .toList(growable: false)
        .toJS,
  );

  SpinifyTransport$WS$PB$JS? transport;

  final eventQueue = EventQueue(); // Event queue for WebSocket events

  // ignore: cancel_subscriptions
  StreamSubscription<web.Event>? onOpen, onError, onMessage, onClose;
  try {
    final completer = Completer<void>();

    // coverage:ignore-start
    onOpen = socket.onOpen.listen((event) {
      eventQueue.add(() {
        if (transport != null || completer.isCompleted) return;
        completer.complete();
      });
    });

    onError = socket.onError.listen((event) {
      eventQueue.add(() async {
        if (transport != null && !transport.disconnected) {
          await transport.disconnect();
          return;
        }
        if (completer.isCompleted) return;
        switch (event) {
          case web.ErrorEvent value
              when value.error != null || value.message.isNotEmpty:
            completer.completeError(Exception(
                'WebSocket connection error: ${value.error ?? value.message}'));
          default:
            completer.completeError(
                Exception('WebSocket connection error: Unknown error'));
        }
      });
    });

    /* socket.onmessage = (web.MessageEvent event) {
      final data = event.data;
      eventQueue.add(() async {
        if (transport == null || transport.disconnected) return;
        final bytes = await _blobCodec.read(data);
        transport._onData(bytes);
      });
    }.toJS; */
    onMessage = socket.onMessage.listen((event) {
      eventQueue.add(() async {
        final bytes = await _blobCodec.read(event.data);
        if (transport == null || transport.disconnected) return;
        transport._onData(bytes);
      });
    });

    onClose = socket.onClose.listen((event) {
      final code = event.code;
      final reason = event.reason;
      eventQueue.add(() async {
        for (final e in [onOpen, onError, onMessage, onClose])
          e?.cancel().ignore();

        if (transport != null && !transport.disconnected) {
          transport
            .._closeCode = code
            .._closeReason = reason
            .._onDone();
          await transport.disconnect(code, reason);
        }

        if (socket.readyState != 3) socket.close(code, reason);
        eventQueue.close(force: true).ignore();

        if (completer.isCompleted) return;
        completer.completeError(
            Exception('WebSocket connection closed: $code $reason'));
      });
    });

    await completer.future;

    // 0	CONNECTING	Socket has been created. The connection is not yet open.
    // 1	OPEN	The connection is open and ready to communicate.
    // 2	CLOSING	The connection is in the process of closing.
    // 3	CLOSED	The connection is closed or couldn't be opened.
    assert(socket.readyState == 1, 'Socket is not open');
    // coverage:ignore-end

    // ignore: join_return_with_assignment
    transport = SpinifyTransport$WS$PB$JS(
      socket,
      config,
      metrics,
      onReply,
      onDisconnect,
    );

    return transport;
  } on Object {
    for (final e in [onOpen, onError, onMessage, onClose]) e?.cancel().ignore();
    if (socket.readyState != 3) socket.close();
    eventQueue.close(force: true).ignore();
    rethrow;
    // coverage:ignore-end
  }
}

/// Create a WebSocket Protocol Buffers transport.
@internal
final class SpinifyTransport$WS$PB$JS implements ISpinifyTransport {
  SpinifyTransport$WS$PB$JS(
    this._socket,
    SpinifyConfig config,
    this._metrics,
    this._onReply,
    this._onDisconnect,
  )   : _logger = config.logger,
        _encoder = switch (config.logger) {
          null => const ProtobufCommandEncoder(),
          _ => ProtobufCommandEncoder(config.logger),
        },
        _decoder = switch (config.logger) {
          null => const ProtobufReplyDecoder(),
          _ => ProtobufReplyDecoder(config.logger),
        },
        disconnected = false;

  final web.WebSocket _socket;
  final Converter<SpinifyCommand, pb.Command> _encoder;
  final Converter<pb.Reply, SpinifyReply> _decoder;
  final SpinifyLogger? _logger;

  bool disconnected;
  int? _closeCode;
  String? _closeReason;

  /// Metrics
  final SpinifyMetrics$Mutable _metrics;

  /// Callback for reply messages
  final void Function(SpinifyReply reply) _onReply;

  /// Callback for disconnect event
  final void Function({required bool temporary}) _onDisconnect;

  /// Fired when data is received through a WebSocket.
  void _onData(Object? bytes) {
    if (bytes is! Uint8List || bytes.isEmpty) {
      assert(false, 'Data is not byte array');
      return;
    }

    _metrics
      ..bytesReceived += bytes.length
      ..messagesReceived += 1;
    final reader = pb.CodedBufferReader(bytes);
    while (!reader.isAtEnd()) {
      try {
        final message = pb.Reply();
        reader.readMessage(message, pb.ExtensionRegistry.EMPTY);
        final reply = _decoder.convert(message);
        _onReply.call(reply);
        _logger?.call(
          const SpinifyLogLevel.transport(),
          'transport_on_reply',
          'Reply ${reply.type}{id: ${reply.id}} received',
          <String, Object?>{
            'protocol': 'protobuf',
            'transport': 'websocket',
            'bytes': bytes,
            'length': bytes.length,
            'reply': reply,
            'protobuf': message,
          },
        );
      } on Object catch (error, stackTrace) {
        _logger?.call(
          const SpinifyLogLevel.error(),
          'transport_on_reply_error',
          'Error reading reply message',
          <String, Object?>{
            'protocol': 'protobuf',
            'transport': 'websocket',
            'bytes': bytes,
            'error': error,
            'stackTrace': stackTrace,
          },
        );
        assert(false, 'Error reading message: $error');
        continue;
      }
    }
  }

  @override
  Future<void> send(SpinifyCommand command) async {
    try {
      final message = _encoder.convert(command);
      final commandData = message.writeToBuffer();
      final length = commandData.lengthInBytes;
      final writer = pb.CodedBufferWriter()
        ..writeInt32NoTag(length); //..writeRawBytes(commandData);
      final bytes = writer.toBuffer() + commandData;
      switch (bytes) {
        case Uint8List uint8List:
          _socket.send(uint8List.toJS);
        case TypedData td:
          _socket.send(Uint8List.view(
            td.buffer,
            td.offsetInBytes,
            td.lengthInBytes,
          ).toJS);
        case List<int> bytes:
          _socket.send(Uint8List.fromList(bytes).toJS);
      }
      _metrics
        ..bytesSent += bytes.length
        ..messagesSent += 1;
      _logger?.call(
        const SpinifyLogLevel.transport(),
        'transport_send',
        'Command ${command.type}{id: ${command.id}} sent',
        <String, Object?>{
          'protocol': 'protobuf',
          'transport': 'websocket',
          'command': command,
          'protobuf': message,
          'length': bytes.length,
          'bytes': bytes,
        },
      );
    } on Object catch (error, stackTrace) {
      _logger?.call(
        const SpinifyLogLevel.error(),
        'transport_send_error',
        'Error sending command ${command.type}{id: ${command.id}}',
        <String, Object?>{
          'protocol': 'protobuf',
          'transport': 'websocket',
          'command': command,
          'error': error,
          'stackTrace': stackTrace,
        },
      );
      rethrow;
    }
  }

  void _onDone() {
    final timestamp = DateTime.now();
    int? code;
    String? reason;
    var reconnect = true;
    if (_closeCode case int closeCode when closeCode > 0) {
      switch (closeCode) {
        case 1009:
          // reconnect is true by default
          code = 3; // disconnectCodeMessageSizeLimit;
          reason = 'message size limit exceeded';
          reconnect = true;
        case < 3000:
          // We expose codes defined by Centrifuge protocol,
          // hiding details about transport-specific error codes.
          // We may have extra optional transportCode field in the future.
          // reconnect is true by default
          code = 1; // connectingCodeTransportClosed;
          reason = _closeReason;
          reconnect = true;
        case >= 3000 && <= 3499:
          // reconnect is true by default
          code = closeCode;
          reason = _closeReason;
          reconnect = true;
        case >= 3500 && <= 3999:
          // application terminal codes
          code = closeCode;
          reason = _closeReason ?? 'application terminal code';
          reconnect = false;
        case >= 4000 && <= 4499:
          // custom disconnect codes
          // reconnect is true by default
          code = closeCode;
          reason = _closeReason;
          reconnect = true;
        case >= 4500 && <= 4999:
          // custom disconnect codes
          // application terminal codes
          code = closeCode;
          reason = _closeReason ?? 'application terminal code';
          reconnect = false;
        case >= 5000:
          // reconnect is true by default
          code = closeCode;
          reason = _closeReason;
          reconnect = true;
        default:
          code = closeCode;
          reason = _closeReason;
          reconnect = false;
      }
    }
    code ??= 1; // connectingCodeTransportClosed
    reason ??= 'transport closed';
    _onReply.call(
      SpinifyPush(
        timestamp: timestamp,
        event: SpinifyDisconnect(
          channel: '', // empty channel
          timestamp: timestamp,
          code: code,
          reason: reason,
          reconnect: reconnect,
        ),
      ),
    );
    _onDisconnect.call(temporary: reconnect);
    _logger?.call(
      const SpinifyLogLevel.transport(),
      'transport_disconnect',
      'Transport disconnected '
          '${reconnect ? 'temporarily' : 'permanently'} '
          'with reason: $reason',
      <String, Object?>{
        'code': code,
        'reason': reason,
        'reconnect': reconnect,
      },
    );
  }

  @override
  Future<void> disconnect([int? code, String? reason]) async {
    disconnected = true;
    _closeCode = code;
    _closeReason = reason;
    if (_socket.readyState == 3)
      return;
    else if (code != null && reason != null)
      _socket.close(code, reason);
    else if (code != null)
      _socket.close(code);
    else
      _socket.close();
    //assert(_socket.readyState == 3, 'Socket is not closed');
  }
}
