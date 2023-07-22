// TODO(plugfox): extract transport from Centrifuge client.
import 'dart:async';

import 'package:centrifuge_dart/src/client/centrifuge_interface.dart';
import 'package:centrifuge_dart/src/model/config.dart';
import 'package:centrifuge_dart/src/model/exception.dart';
import 'package:centrifuge_dart/src/model/state.dart';
import 'package:centrifuge_dart/src/transport/transport_interface.dart';
import 'package:centrifuge_dart/src/transport/ws_protobuf_transport.dart';
import 'package:meta/meta.dart';

/// {@template centrifuge}
/// Centrifuge client.
/// {@endtemplate}
final class Centrifuge extends CentrifugeBase
    with CentrifugePingMixin, CentrifugeConnectionMixin {
  /// {@macro centrifuge}
  Centrifuge([CentrifugeConfig? config])
      : super(config ?? CentrifugeConfig.defaultConfig());

  /// Create client and connect.
  ///
  /// {@macro centrifuge}
  factory Centrifuge.connect(String url, [CentrifugeConfig? config]) =>
      Centrifuge(config)..connect(url);
}

/// {@nodoc}
@internal
abstract base class CentrifugeBase implements ICentrifuge {
  /// {@nodoc}
  CentrifugeBase(CentrifugeConfig config)
      : _transport = CentrifugeWebSocketProtobufTransport(
          timeout: config.timeout,
          headers: config.headers,
        ),
        _config = config {
    _initCentrifuge();
  }

  /// Internal transport responsible
  /// for sending, receiving, encoding and decoding data from the server.
  /// {@nodoc}
  @nonVirtual
  final ICentrifugeTransport _transport;

  @override
  @nonVirtual
  CentrifugeState get state => _transport.state;

  @override
  Stream<CentrifugeState> get states => _transport.states;

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
base mixin CentrifugeConnectionMixin on CentrifugeBase, CentrifugePingMixin {
  @override
  Future<void> connect(String url) async {
    try {
      await _transport.connect(
        url: url,
        client: _config.client,
        getToken: _config.getToken,
        getPayload: _config.getPayload,
      );
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        CentrifugeConnectionException(error),
        stackTrace,
      );
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await _transport.disconnect();
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        CentrifugeDisconnectionException(error),
        stackTrace,
      );
    }
  }

  @override
  Future<void> close() async {
    await super.close();
    await _transport.close();
  }
}

/// Mixin responsible for sending ping to server.
/// {@nodoc}
base mixin CentrifugePingMixin on CentrifugeBase {
  Timer? _pingTimer;

  @nonVirtual
  void _setUpPingTimer() {}

  @nonVirtual
  void _tearDownPingTimer() {
    _pingTimer?.cancel();
  }

  /* @override
  Future<void> send(List<int> data) async {
    final request = pb.Message()..data = data;
    final command = _createCommand(
      request,
      true,
    );
    await _webSocket.add(request);
    /* try {
      final request = protocol.Message()..data = data;
      await _webSocket.add(data);
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        CentrifugeSendException(error),
        stackTrace,
      );
    } */
  } */

  @override
  Future<void> close() async {
    _tearDownPingTimer();
    await super.close();
  }
}
