import 'dart:async';

import 'package:meta/meta.dart';

import 'model/exception.dart';
import 'model/transport_interface.dart';

/// Fake WebSocket implementation.
@visibleForTesting
class WebSocket$Fake implements WebSocket {
  /// Create a fake WebSocket.
  WebSocket$Fake({
    StreamController<List<int>>? socket,
  }) : _socket = socket ?? StreamController<List<int>>() {
    stream = _socket.stream.transform<List<int>>(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: _dataHandler,
        handleError: _errorHandler,
        handleDone: _doneHandler,
      ),
    );
  }

  final StreamController<List<int>> _socket;

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
  late final Stream<List<int>> stream;

  @override
  void add(List<int> event) {}

  @override
  void close([int? code, String? reason]) {
    _closeCode = code;
    _closeReason = reason;
    _socket.close().ignore();
  }
}
