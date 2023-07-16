import 'dart:async';

import 'package:centrifuge_dart/src/client/centrifuge_interface.dart';
import 'package:centrifuge_dart/src/model/config.dart';
import 'package:centrifuge_dart/src/model/exception.dart';
import 'package:centrifuge_dart/src/model/state.dart';
import 'package:meta/meta.dart';
import 'package:ws/ws.dart';

/// {@template centrifuge}
/// Centrifuge client.
/// {@endtemplate}
final class Centrifuge = CentrifugeBase with CentrifugeConnectionMixin;

/// {@nodoc}
@internal
abstract base class CentrifugeBase implements ICentrifuge {
  /// {@nodoc}
  CentrifugeBase([CentrifugeConfig? config])
      : _stateController = StreamController<CentrifugeState>.broadcast(),
        _webSocket = WebSocketClient(
          reconnectTimeout: Duration.zero,
          protocols: _$protocolsCentrifugeProtobuf,
        ),
        _state = CentrifugeState$Disconnected(),
        _config = config ?? CentrifugeConfig.defaultConfig() {
    _initCentrifuge();
  }

  /// Protocols for websocket.
  /// {@nodoc}
  static const List<String> _$protocolsCentrifugeProtobuf = <String>[
    'centrifuge-protobuf'
  ];

  /// State controller.
  /// {@nodoc}
  final StreamController<CentrifugeState> _stateController;

  /// Websocket client.
  /// {@nodoc}
  final WebSocketClient _webSocket;

  @override
  CentrifugeState get state => _state;

  /// Current state of client.
  /// {@nodoc}
  CentrifugeState _state;

  @override
  late Stream<CentrifugeState> states = _stateController.stream;

  /// Centrifuge config.
  /// {@nodoc}
  final CentrifugeConfig _config;

  /// Init centrifuge client, override this method to add custom logic.
  /// This method is called in constructor.
  /// {@nodoc}
  @protected
  @mustCallSuper
  void _initCentrifuge() {}

  /// {@nodoc}
  @protected
  @nonVirtual
  void _setState(CentrifugeState state) {
    if (_state.type == state.type) return;
    _stateController.add(_state = state);
  }

  @override
  @mustCallSuper
  Future<void> close() async {}
}

/// Mixin responsible for connection.
/// {@nodoc}
@internal
base mixin CentrifugeConnectionMixin on CentrifugeBase {
  StreamSubscription<WebSocketClientState>? _webSocketStateSubscription;

  @override
  void _initCentrifuge() {
    _webSocketStateSubscription = _webSocket.stateChanges.listen((state) {
      switch (state) {
        case WebSocketClientState$Connecting state:
          _setState(CentrifugeState$Connecting(url: state.url));
        case WebSocketClientState$Open _:
          _setState(CentrifugeState$Connected(url: state.url));
        case WebSocketClientState$Disconnecting _:
        case WebSocketClientState$Closed _:
          _setState(CentrifugeState$Disconnected());
      }
    });
    super._initCentrifuge();
  }

  @override
  Future<void> connect(String url) async {
    _setState(CentrifugeState$Connecting(url: url));
    try {
      await _webSocket.connect(url);
    } on Object catch (error, stackTrace) {
      _setState(CentrifugeState$Disconnected());
      Error.throwWithStackTrace(
        CentrifugoConnectionException(error),
        stackTrace,
      );
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await _webSocket.disconnect();
    } on Object catch (error, stackTrace) {
      _setState(CentrifugeState$Disconnected());
      Error.throwWithStackTrace(
        CentrifugoConnectionException(error),
        stackTrace,
      );
    }
  }

  @override
  @mustCallSuper
  Future<void> close() async {
    await super.close();
    await _webSocket.close();
    await _webSocketStateSubscription?.cancel();
  }
}
