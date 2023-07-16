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
final class Centrifuge extends CentrifugeBase with CentrifugeConnectionMixin {
  /// {@macro centrifuge}
  Centrifuge([CentrifugeConfig? config])
      : super(config ?? CentrifugeConfig.defaultConfig());

  /// Create client and connect.
  ///
  /// {@macro centrifuge}
  factory Centrifuge.connect(String url, [CentrifugeConfig? config]) =>
      Centrifuge(config ?? CentrifugeConfig.defaultConfig())..connect(url);
}

/// {@nodoc}
@internal
abstract base class CentrifugeBase implements ICentrifuge {
  /// {@nodoc}
  CentrifugeBase(CentrifugeConfig config)
      : _stateController = StreamController<CentrifugeState>.broadcast(),
        _webSocket = WebSocketClient(
          WebSocketOptions.selector(
            js: () => WebSocketOptions.js(
              connectionRetryInterval: config.connectionRetryInterval,
              protocols: _$protocolsCentrifugeProtobuf,
              timeout: config.timeout,
              useBlobForBinary: false,
            ),
            vm: () => WebSocketOptions.vm(
              connectionRetryInterval: config.connectionRetryInterval,
              protocols: _$protocolsCentrifugeProtobuf,
              timeout: config.timeout,
              headers: config.headers,
            ),
          ),
        ),
        _state = CentrifugeState$Disconnected(),
        _config = config {
    _initCentrifuge();
  }

  /// Protocols for websocket.
  /// {@nodoc}
  static const List<String> _$protocolsCentrifugeProtobuf = <String>[
    'centrifuge-protobuf'
  ];

  /// State controller.
  /// {@nodoc}
  @nonVirtual
  final StreamController<CentrifugeState> _stateController;

  /// Websocket client.
  /// {@nodoc}
  @nonVirtual
  final WebSocketClient _webSocket;

  @override
  @nonVirtual
  CentrifugeState get state => _state;

  /// Current state of client.
  /// {@nodoc}
  @nonVirtual
  CentrifugeState _state;

  @override
  late Stream<CentrifugeState> states = _stateController.stream;

  /// Centrifuge config.
  /// {@nodoc}
  @nonVirtual
  final CentrifugeConfig _config;

  /// Init centrifuge client, override this method to add custom logic.
  /// This method is called in constructor.
  /// {@nodoc}
  @protected
  @mustCallSuper
  void _initCentrifuge() {}

  @override
  @mustCallSuper
  Future<void> close() async {}
}

/// Mixin responsible for connection.
/// {@nodoc}
@internal
base mixin CentrifugeConnectionMixin on CentrifugeBase {
  StreamSubscription<WebSocketClientState>? _webSocketStateSubscription;

  /// {@nodoc}
  @protected
  @nonVirtual
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  void _setState(CentrifugeState state) {
    if (_state.type == state.type) return;
    _stateController.add(_state = state);
  }

  @override
  void _initCentrifuge() {
    /// Listen to websocket state changes and update current client state.
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
      Error.throwWithStackTrace(
        CentrifugoDisconnectionException(error),
        stackTrace,
      );
    }
  }

  @override
  @mustCallSuper
  Future<void> close() async {
    await super.close();
    await _webSocket.close();
    _webSocketStateSubscription?.cancel().ignore();
  }
}
