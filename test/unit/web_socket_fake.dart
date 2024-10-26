// ignore_for_file: use_setters_to_change_properties

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:spinify/spinify.dart';
import 'package:spinify/src/protobuf/client.pb.dart' as pb;

import 'codecs.dart';

/// Fake WebSocket implementation.
@visibleForTesting
class WebSocket$Fake implements WebSocket {
  /// Create a fake WebSocket.
  WebSocket$Fake() {
    _init();
  }

  void _init() {
    _socket?.close();
    // ignore: close_sinks
    final controller = _socket = StreamController<List<int>>(sync: true);
    _stream = controller.stream.transform<List<int>>(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: _dataHandler,
        handleError: _errorHandler,
        handleDone: _doneHandler,
      ),
    );
    onAdd = _defaultOnAddCallback;
  }

  // Default callbacks to handle connects and disconnects.
  static void _defaultOnAddCallback(List<int> bytes, Sink<List<int>> sink) {
    final command = ProtobufCodec.decode(pb.Command(), bytes);
    scheduleMicrotask(() {
      if (command.hasConnect()) {
        sink.add(
          ProtobufCodec.encode(
            pb.Reply(
              id: command.id,
              connect: pb.ConnectResult(
                client: 'fake',
                version: '0.0.1',
                expires: false,
                ttl: null,
                data: null,
                subs: <String, pb.SubscribeResult>{},
                ping: 600,
                pong: false,
                session: 'fake',
                node: 'fake',
              ),
            ),
          ),
        );
      }
    });
  }

  StreamController<List<int>>? _socket;

  Stream<List<int>>? _stream;

  @override
  Stream<List<int>> get stream => _stream ?? const Stream<List<int>>.empty();

  /// Handle incoming data.
  void _dataHandler(List<int> data, EventSink<List<int>> sink) =>
      sink.add(data);

  /// Handle incoming error.
  void _errorHandler(
    Object error,
    StackTrace stackTrace,
    EventSink<List<int>> sink,
  ) =>
      sink.addError(
        SpinifyTransportException(
          message: 'Fake WebSocket error',
          error: error,
        ),
        stackTrace,
      );

  /// Handle socket close.
  void _doneHandler(EventSink<List<int>> sink) {
    sink.close();
    _isClosed = true;
    _onDoneCallback?.call();
  }

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
  void add(List<int> bytes) {
    onAdd(bytes, _socket!.sink);
  }

  /// Add callback to handle sending data and allow to respond with reply.
  void Function(List<int> bytes, Sink<List<int>> sink) onAdd =
      _defaultOnAddCallback;

  void Function()? _onDoneCallback;

  /// Add callback to handle socket close event.
  void onDone(void Function()? callback) {
    _onDoneCallback = callback;
  }

  /// Send asynchroniously a reply to the client.
  void reply(List<int> bytes) {
    _socket!.sink.add(bytes);
  }

  @override
  void close([int? code, String? reason]) {
    _closeCode = code;
    _closeReason = reason;
    _isClosed = true;
    _socket!.close().ignore();
  }

  /// Reset the WebSocket client.
  void reset() {
    _closeCode = null;
    _closeReason = null;
    _isClosed = false;
    _onDoneCallback = null;
    _init();
  }
}
