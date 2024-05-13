import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:meta/meta.dart';
import 'package:protobuf/protobuf.dart' as pb;

import 'model/command.dart';
import 'model/config.dart';
import 'model/reply.dart';
import 'model/transport_interface.dart';
import 'protobuf/client.pb.dart' as pb;
import 'protobuf/protobuf_codec.dart';

/// Create a WebSocket Protocol Buffers transport.
@internal
Future<ISpinifyTransport> $create$WS$PB$Transport(
  String url,
  SpinifyConfig config,
) async {
  // ignore: close_sinks
  final socket = await io.WebSocket.connect(
    url,
    headers: config.headers,
    protocols: <String>{'centrifuge-protobuf'},
  );
  final transport = SpinifyTransport$WS$PB$VM(socket, config);
  // 0	CONNECTING	Socket has been created. The connection is not yet open.
  // 1	OPEN	The connection is open and ready to communicate.
  // 2	CLOSING	The connection is in the process of closing.
  // 3	CLOSED	The connection is closed or couldn't be opened.
  assert(socket.readyState == io.WebSocket.open, 'Socket is not open');
  return transport;
}

/// Create a WebSocket Protocol Buffers transport.
@internal
final class SpinifyTransport$WS$PB$VM implements ISpinifyTransport {
  SpinifyTransport$WS$PB$VM(this._socket, SpinifyConfig config)
      : _logger = config.logger,
        _encoder = switch (config.logger) {
          null => const ProtobufCommandEncoder(),
          _ => ProtobufCommandEncoder(config.logger),
        },
        _decoder = switch (config.logger) {
          null => const ProtobufReplyDecoder(),
          _ => ProtobufReplyDecoder(config.logger),
        } {
    _subscription = _socket.listen(
      _onData,
      cancelOnError: false,
      onDone: () {
        assert(_onDisconnect != null, 'Disconnect handler is not set');
        _onDisconnect?.call();
      },
    );
  }

  final io.WebSocket _socket;
  final Converter<SpinifyCommand, pb.Command> _encoder;
  final Converter<pb.Reply, SpinifyReply> _decoder;
  final SpinifyLogger? _logger;
  late final StreamSubscription<dynamic> _subscription;

  void Function(SpinifyReply reply)? _onReply;

  @override
  // ignore: avoid_setters_without_getters
  set onReply(void Function(SpinifyReply reply) handler) => _onReply = handler;

  @override
  // ignore: avoid_setters_without_getters
  set onDisconnect(void Function() handler) => _onDisconnect = handler;
  void Function()? _onDisconnect;

  void _onData(Object? bytes) {
    if (bytes is! List<int> || bytes.isEmpty) {
      assert(false, 'Data is not byte array');
      return;
    }
    assert(_onReply != null, 'Reply handler is not set');
    final reader = pb.CodedBufferReader(bytes);
    while (!reader.isAtEnd()) {
      try {
        final message = pb.Reply();
        reader.readMessage(message, pb.ExtensionRegistry.EMPTY);
        final reply = _decoder.convert(message);
        _onReply?.call(reply);
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
      _socket.add(bytes);
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

  @override
  Future<void> disconnect([int? code, String? reason]) async {
    await _subscription.cancel();
    await _socket.close(code, reason);
    //assert(_socket.readyState == io.WebSocket.closed, 'Socket is not closed');
  }
}
