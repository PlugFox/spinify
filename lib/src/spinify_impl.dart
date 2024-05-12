import 'dart:async';

import 'package:meta/meta.dart';

import 'model/command.dart';
import 'model/config.dart';
import 'model/history.dart';
import 'model/metrics.dart';
import 'model/presence.dart';
import 'model/presence_stats.dart';
import 'model/pushes_stream.dart';
import 'model/reply.dart';
import 'model/spinify_interface.dart';
import 'model/state.dart';
import 'model/states_stream.dart';
import 'model/stream_position.dart';
import 'model/subscription_config.dart';
import 'model/subscription_interface.dart';
import 'model/transport_interface.dart';
import 'transport_ws_pb_stub.dart'
    // ignore: uri_does_not_exist
    if (dart.library.html) 'transport_ws_pb_js.dart'
    // ignore: uri_does_not_exist
    if (dart.library.io) 'transport_ws_pb_vm.dart';

/// Base class for Spinify client.
abstract base class SpinifyBase implements ISpinify {
  /// Create a new Spinify client.
  SpinifyBase({required this.config}) {
    _init();
  }

  /// Counter for command messages.
  int _commandId = 1;
  int _getNextCommandId() => _commandId++;

  @override
  bool get isClosed => state.isClosed;

  /// Spinify config.
  @override
  @nonVirtual
  final SpinifyConfig config;

  late final CreateSpinifyTransport _createTransport;
  ISpinifyTransport? _transport;

  /// Client initialization (from constructor).
  @mustCallSuper
  void _init() {
    _createTransport = $create$WS$PB$Transport;
  }

  /// On connect to the server.
  @mustCallSuper
  Future<void> _onConnect(String url) async {}

  @mustCallSuper
  Future<void> _onReply(SpinifyReply reply) async {}

  /// On disconnect from the server.
  @mustCallSuper
  Future<void> _onDisconnect() async {}

  @override
  Future<void> close() async {}
}

/// Base mixin for Spinify client state management.
base mixin SpinifyStateMixin on SpinifyBase {
  @override
  SpinifyState get state => _state;
  SpinifyState _state = SpinifyState$Disconnected();

  @override
  late final SpinifyStatesStream states =
      SpinifyStatesStream(_statesController.stream);

  @nonVirtual
  final StreamController<SpinifyState> _statesController =
      StreamController<SpinifyState>.broadcast();

  @nonVirtual
  void _setState(SpinifyState state) => _statesController.add(_state = state);

  @override
  Future<void> _onConnect(String url) async {
    _setState(SpinifyState$Connecting(url: url));
    await super._onConnect(url);
  }

  @override
  Future<void> _onDisconnect() async {
    await super._onDisconnect();
    if (!state.isDisconnected) _setState(SpinifyState$Disconnected());
  }

  @override
  Future<void> close() async {
    await super.close();
    if (!state.isClosed) _setState(SpinifyState$Closed());
    await _statesController.close();
  }
}

/// Base mixin for Spinify command sending.
base mixin SpinifyCommandMixin on SpinifyBase {
  final Map<int, Completer<SpinifyReply>> _replies =
      <int, Completer<SpinifyReply>>{};

  @override
  Future<void> send(List<int> data) => _sendCommandAsync(SpinifySendRequest(
        id: _getNextCommandId(),
        timestamp: DateTime.now(),
        data: data,
      ));

  Future<T> _sendCommand<T extends SpinifyReply>(SpinifyCommand command) async {
    try {
      assert(command.id > -1, 'Command ID should be greater or equal to 0');
      assert(_replies[command.id] == null, 'Command ID should be unique');
      assert(_transport != null, 'Transport is not connected');
      assert(state.isConnected, 'State is not connected');
      final completer = _replies[command.id] = Completer<T>();
      await _sendCommandAsync(command);
      return await completer.future.timeout(config.timeout);
    } on Object catch (error, stackTrace) {
      final completer = _replies.remove(command.id);
      if (completer != null && !completer.isCompleted)
        completer.completeError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> _sendCommandAsync(SpinifyCommand command) async {
    assert(command.id > -1, 'Command ID should be greater or equal to 0');
    assert(_transport != null, 'Transport is not connected');
    assert(state.isConnected, 'State is not connected');
    await _transport?.send(command);
  }

  @override
  Future<void> _onReply(SpinifyReply reply) async {
    if (reply.id case int id when id > 0) _replies.remove(id)?.complete(reply);
    await super._onReply(reply);
  }

  @override
  Future<void> _onDisconnect() async {
    late final error = StateError('Client is disconnected');
    for (final completer in _replies.values) completer.completeError(error);
    _replies.clear();
    await super._onDisconnect();
  }
}

/// Base mixin for Spinify client connection management (connect & disconnect).
base mixin SpinifyConnectionMixin
    on SpinifyBase, SpinifyCommandMixin, SpinifyStateMixin {
  Completer<void>? _readyCompleter;

  @override
  Future<void> connect(String url) async {
    try {
      // Disconnect previous transport if exists.
      _transport?.disconnect(1000, 'Reconnecting').ignore();

      // Create new transport.
      _transport = await _createTransport(url, config.headers)
        ..onReply = _onReply
        ..onDisconnect = () => _onDisconnect().ignore();

      // Prepare connect request.
      final request = await _prepareConnectRequest();

      final reply = await _sendCommand<SpinifyConnectResult>(request);
      _setState(SpinifyState$Connected(
        url: url,
        timestamp: DateTime.now(),
        client: reply.client,
        version: reply.version,
        expires: reply.expires,
        ttl: reply.ttl,
        node: reply.node,
        pingInterval: reply.pingInterval,
        sendPong: reply.sendPong,
        session: reply.session,
        data: reply.data,
      ));

      // Notify ready.
      _readyCompleter?.complete();
      _readyCompleter = null;
    } on Object catch (error, stackTrace) {
      _readyCompleter?.completeError(error, stackTrace);
      rethrow;
    }
  }

  Future<SpinifyConnectRequest> _prepareConnectRequest() async {
    final token = await config.getToken?.call();
    assert(token == null || token.length > 5, 'Spinify JWT is too short');
    final payload = await config.getPayload?.call();
    return SpinifyConnectRequest(
      id: _getNextCommandId(),
      timestamp: DateTime.now(),
      token: token,
      data: payload,
      // TODO(plugfox): Implement subscriptions.
      subs: const <String, SpinifySubscribeRequest>{},
      name: config.client.name,
      version: config.client.version,
    );
  }

  @override
  Future<void> ready() async {
    if (state.isConnected) return;
    return (_readyCompleter ??= Completer<void>()).future;
  }

  @override
  Future<void> disconnect() async {
    if (state.isDisconnected) return Future.value();
    await _transport?.disconnect(1000, 'Client disconnecting');
    await _onDisconnect();
  }

  @override
  Future<void> _onDisconnect() async {
    _transport = null;
    await super._onDisconnect();
  }

  @override
  Future<void> close() async {
    await _transport?.disconnect(1000, 'Client closing');
    await super.close();
  }
}

/// Base mixin for Spinify client ping-pong management.
base mixin SpinifyPingPongMixin
    on SpinifyBase, SpinifyStateMixin, SpinifyConnectionMixin {
  @protected
  @nonVirtual
  Timer? _pingTimer;

  /* @override
  Future<void> ping() => _bucket.push(
      ClientEvent.command,
      (int id, DateTime timestamp) => SpinifyPingRequest(
            id: id,
            timestamp: timestamp,
          )); */

  /// Stop keepalive timer.
  @protected
  @nonVirtual
  void _tearDownPingTimer() => _pingTimer?.cancel();

  /// Start or restart keepalive timer,
  /// you should restart it after each received ping message.
  /// Or connection will be closed by timeout.
  @protected
  @nonVirtual
  void _restartPingTimer() {
    _tearDownPingTimer();
    assert(!isClosed, 'Client is closed');
    assert(state.isConnected, 'Invalid state');
    if (state case SpinifyState$Connected(:Duration? pingInterval)
        when pingInterval != null && pingInterval > Duration.zero) {
      _pingTimer = Timer(
        pingInterval + config.serverPingDelay,
        () {
          // Reconnect if no pong received.
          if (state case SpinifyState$Connected(:String url)) connect(url);
          /* disconnect(
            SpinifyConnectingCode.noPing,
            'No ping from server',
          ); */
        },
      );
    }
  }

  @override
  Future<void> _onConnect(String url) async {
    _tearDownPingTimer();
    await super._onConnect(url);
    _restartPingTimer();
  }

  @override
  Future<void> _onReply(SpinifyReply reply) async {
    if (reply is SpinifyServerPing) {
      await _sendCommandAsync(SpinifyPingRequest(timestamp: DateTime.now()));
      _restartPingTimer();
    }
    await super._onReply(reply);
  }

  @override
  Future<void> _onDisconnect() async {
    _tearDownPingTimer();
    await super._onDisconnect();
  }

  @override
  Future<void> close() async {
    _tearDownPingTimer();
    await super.close();
  }
}

/// Base mixin for Spinify client subscription management.
base mixin SpinifyClientSubscriptionMixin on SpinifyBase {
  @override
  ({
    Map<String, SpinifyClientSubscription> client,
    Map<String, SpinifyServerSubscription> server
  }) get subscriptions => throw UnimplementedError();

  @override
  SpinifyClientSubscription? getSubscription(String channel) =>
      throw UnimplementedError();

  @override
  SpinifyClientSubscription newSubscription(String channel,
          [SpinifySubscriptionConfig? config]) =>
      throw UnimplementedError();

  @override
  Future<void> removeSubscription(SpinifyClientSubscription subscription) =>
      throw UnimplementedError();
}

/// Base mixin for Spinify server subscription management.
base mixin SpinifyServerSubscriptionMixin on SpinifyBase {}

/// Base mixin for Spinify client publications management.
base mixin SpinifyPublicationsMixin on SpinifyBase {
  @override
  Future<void> publish(String channel, List<int> data) =>
      throw UnimplementedError();
}

/// Base mixin for Spinify client presence management.
base mixin SpinifyPresenceMixin on SpinifyBase {
  @override
  Future<SpinifyPresence> presence(String channel) =>
      throw UnimplementedError();

  @override
  Future<SpinifyPresenceStats> presenceStats(String channel) =>
      throw UnimplementedError();
}

/// Base mixin for Spinify client history management.
base mixin SpinifyHistoryMixin on SpinifyBase {
  @override
  Future<SpinifyHistory> history(
    String channel, {
    int? limit,
    SpinifyStreamPosition? since,
    bool? reverse,
  }) =>
      throw UnimplementedError();
}

/// Base mixin for Spinify client RPC management.
base mixin SpinifyRPCMixin on SpinifyBase {
  @override
  Future<List<int>> rpc(String method, List<int> data) =>
      throw UnimplementedError();
}

/// Base mixin for Spinify client metrics management.
base mixin SpinifyMetricsMixin on SpinifyBase {
  @override
  SpinifyMetrics get metrics => throw UnimplementedError();
}

/// {@template spinify}
/// Spinify client for Centrifuge.
///
/// Centrifugo SDKs use WebSocket as the main data transport and send/receive
/// messages encoded according to our bidirectional protocol.
/// That protocol is built on top of the Protobuf schema
/// (both JSON and binary Protobuf formats are supported).
/// It provides asynchronous communication, sending RPC,
/// multiplexing subscriptions to channels, etc.
///
/// Client SDK wraps the protocol and exposes a set of APIs to developers.
///
/// Client connection has 4 states:
/// - [SpinifyState$Disconnected]
/// - [SpinifyState$Connecting]
/// - [SpinifyState$Connected]
/// - [SpinifyState$Closed]
///
/// {@endtemplate}
/// {@category Client}
final class Spinify extends SpinifyBase
    with
        SpinifyStateMixin,
        SpinifyCommandMixin,
        SpinifyConnectionMixin,
        SpinifyPingPongMixin,
        SpinifyClientSubscriptionMixin,
        SpinifyServerSubscriptionMixin,
        SpinifyPublicationsMixin,
        SpinifyPresenceMixin,
        SpinifyHistoryMixin,
        SpinifyRPCMixin,
        SpinifyMetricsMixin {
  /// {@macro spinify}
  Spinify({SpinifyConfig? config})
      : super(config: config ?? SpinifyConfig.byDefault());

  /// Create client and connect.
  ///
  /// {@macro spinify}
  factory Spinify.connect(String url, {SpinifyConfig? config}) =>
      Spinify(config: config)..connect(url);

  @override
  SpinifyPushesStream get stream => throw UnimplementedError();
}
