import 'dart:async';
import 'dart:io' as io;

import 'package:meta/meta.dart';

import 'model/command.dart';
import 'model/reply.dart';
import 'model/transport_interface.dart';
import 'protobuf/protobuf_codec.dart';

/// Create a WebSocket Protocol Buffers transport.
@internal
Future<ISpinifyTransport> $create$WS$PB$Transport(
  String url,
  Map<String, String> headers,
) async {
  // ignore: close_sinks
  final socket = await io.WebSocket.connect(url, headers: headers);
  final transport = SpinifyTransport$WS$PB$VM(socket);
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
  SpinifyTransport$WS$PB$VM(this._socket) {
    _subscription = _socket.listen(
      _onData,
      cancelOnError: false,
    );
  }

  final io.WebSocket _socket;
  late final StreamSubscription<dynamic> _subscription;

  void Function(SpinifyReply reply)? _handler;

  @override
  // ignore: avoid_setters_without_getters
  set onReply(void Function(SpinifyReply reply) handler) => _handler = handler;

  void _onData(Object? bytes) {
    const decoder = ProtobufReplyDecoder();
    if (bytes is! List<int> || bytes.isEmpty) {
      assert(false, 'Data is not byte array');
      return;
    }
    final reply = decoder.convert(bytes);
    assert(_handler != null, 'Handler is not set');
    _handler?.call(reply);
  }

  @override
  Future<void> send(SpinifyCommand command) async {
    const encoder = ProtobufCommandEncoder();
    final bytes = encoder.convert(command);
    _socket.add(bytes);
  }

  @override
  Future<void> disconnect([int? code, String? reason]) async {
    await _subscription.cancel();
    await _socket.close(code, reason);
    assert(_socket.readyState == io.WebSocket.closed, 'Socket is not closed');
  }
}
