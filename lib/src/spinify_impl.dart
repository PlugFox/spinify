// ignore_for_file: avoid_types_on_closure_parameters

import 'dart:async';

import 'package:meta/meta.dart';

import '../spinify_developer.dart';
import 'event_bus.dart';
import 'model/codes.dart';
import 'model/command.dart';
import 'model/config.dart';
import 'model/event_bus_events.dart';
import 'model/history.dart';
import 'model/metrics.dart';
import 'model/presence.dart';
import 'model/presence_stats.dart';
import 'model/pushes_stream.dart';
import 'model/reply.dart';
import 'model/states_stream.dart';
import 'model/stream_position.dart';
import 'model/subscription_config.dart';
import 'model/subscription_interface.dart';
import 'transport_ws_pb_stub.dart'
    // ignore: uri_does_not_exist
    if (dart.library.html) 'transport_ws_pb_js.dart'
    // ignore: uri_does_not_exist
    if (dart.library.io) 'transport_ws_pb_vm.dart';

/// Subscriptions to the callbacks from the Event Bus.
abstract base class SpinifyCallbacks {
  @mustCallSuper
  void _initCallbacks(ISpinifyEventBus$Bucket bucket) {
    Future<void> Function(Object?) castCallback<T>(
            Future<void> Function(T data) fn) =>
        (data) {
          if (data is T) return fn(data);
          assert(false,
              'Unexpected data type: "${data.runtimeType}" instead of "$T"');
          return Future<void>.value();
        };

    void subVoid(Enum event, Future<void> Function() callback) =>
        bucket.subscribe(event, (_) => callback());

    void subValue<T>(Enum event, Future<void> Function(T data) callback) =>
        bucket.subscribe(event, castCallback(callback));

    subVoid(ClientEvent.init, _onInit);
    subValue(ClientEvent.connect, _onConnect);
    subValue(ClientEvent.disconnect, _onDisconnect);
    subValue(ClientEvent.command, _onCommand);
    subVoid(ClientEvent.close, _onClose);

    bucket.push(ClientEvent.init);
  }

  /// On complete client initialization (from constructor).
  @mustCallSuper
  Future<void> _onInit() async {}

  /// On connect to the server.
  @mustCallSuper
  Future<void> _onConnect(String url) async {}

  /// On disconnect from the server.
  @mustCallSuper
  Future<void> _onDisconnect(({int? code, String? reason}) arg) async {}

  /// On command received.
  /// [command] - received command.
  ///
  /// Called on:
  /// - [connect]
  /// - [subscribe]
  /// - [unsubscribe]
  /// - [publish]
  /// - [presence]
  /// - [presenceStats]
  /// - [history]
  /// - [ping]
  /// - [send]
  /// - [rpc]
  /// - [refresh]
  /// - [subRefresh]
  @mustCallSuper
  Future<void> _onCommand(SpinifyCommandBuilder builder) async {}

  /// On reply received.
  @mustCallSuper
  Future<void> _onReply(SpinifyReply reply) async {}

  /// On close client.
  @mustCallSuper
  Future<void> _onClose() async {}
}

/// Base class for Spinify client.
abstract base class SpinifyBase extends SpinifyCallbacks implements ISpinify {
  /// Create a new Spinify client.
  SpinifyBase({required this.config, CreateSpinifyTransport? createTransport})
      : id = _idCounter++,
        _createTransport = createTransport ?? $create$WS$PB$Transport {
    _bucket = SpinifyEventBus.instance.registerClient(this);
    _initCallbacks(_bucket);
    _bucket.push(ClientEvent.init);
  }

  /// Unique client ID counter for Spinify clients.
  static int _idCounter = 0;

  @override
  final int id;

  /// Counter for command messages.
  int _commandId = 1;
  int _getNextCommandId() => _commandId++;

  @override
  bool get isClosed => _isClosed;
  bool _isClosed = false;

  /// Spinify config.
  @override
  @nonVirtual
  final SpinifyConfig config;

  /// Event Bus Bucket for client events and event subscriptions.
  late final ISpinifyEventBus$Bucket _bucket;
  final CreateSpinifyTransport _createTransport;
  ISpinifyTransport? _transport;

  @override
  Future<void> _onDisconnect(({int? code, String? reason}) arg) async {
    await super._onDisconnect(arg);
    assert(_transport == null, 'Transport is not disconnected');
  }

  @override
  Future<void> _onClose() async {
    assert(_transport == null, 'Transport is not closed');
    await super._onClose();
    _isClosed = true;
    SpinifyEventBus.instance.unregisterClient(this);
  }

  @override
  @mustCallSuper
  Future<void> close() => _bucket.push(ClientEvent.close);

  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  int get hashCode => id;

  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  bool operator ==(Object other) =>
      identical(this, other) || other is SpinifyBase && id == other.id;

  @override
  String toString() => 'Spinify{}';
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
    _setState(SpinifyState$Connecting(
      url: url,
      timestamp: DateTime.now(),
    ));
    await super._onConnect(url);
  }

  @override
  Future<void> _onDisconnect(({int? code, String? reason}) arg) async {
    await super._onDisconnect(arg);
    _setState(SpinifyState$Disconnected(
      closeCode: arg.code,
      closeReason: arg.reason,
      timestamp: DateTime.now(),
    ));
  }

  @override
  Future<void> _onClose() async {
    await super._onClose();
    _setState(SpinifyState$Closed(timestamp: DateTime.now()));
  }
}

/// Base mixin for Spinify command sending.
base mixin SpinifyCommandMixin on SpinifyBase {
  final Map<int, Completer<SpinifyReply>> _replies =
      <int, Completer<SpinifyReply>>{};

  @override
  Future<void> send(List<int> data) => _bucket.push(
      ClientEvent.command,
      (int id, DateTime timestamp) => SpinifySendRequest(
            id: id,
            timestamp: timestamp,
            data: data,
          ));

  @override
  Future<void> _onCommand(SpinifyCommandBuilder builder) async {
    await super._onCommand(builder);
    final command = builder(_getNextCommandId(), DateTime.now());
    switch (command) {
      case SpinifySendRequest send:
        await _sendCommandAsync(send);
      default:
        await _sendCommand(command);
    }
  }

  Future<T> _sendCommand<T extends SpinifyReply>(SpinifyCommand command) async {
    final completer = _replies[command.id] = Completer<T>();
    await _sendCommandAsync(command);
    return completer.future;
  }

  Future<void> _sendCommandAsync(SpinifyCommand command) async {
    assert(command.id > 0, 'Command ID is not set');
    assert(_transport != null, 'Transport is not connected');
    await _transport?.send(command);
  }

  @override
  Future<void> _onReply(SpinifyReply reply) async {
    _replies.remove(reply.id)?.complete(reply);
    await super._onReply(reply);
  }

  @override
  Future<void> _onDisconnect(({int? code, String? reason}) arg) async {
    for (final completer in _replies.values) {
      completer.completeError(StateError('Client is disconnected'));
    }
    await super._onDisconnect(arg);
  }
}

/// Base mixin for Spinify client connection management (connect & disconnect).
base mixin SpinifyConnectionMixin
    on SpinifyBase, SpinifyCommandMixin, SpinifyStateMixin {
  Completer<void>? _readyCompleter;

  @override
  Future<void> connect(String url) => _bucket.push(ClientEvent.connect, url);

  @override
  Future<void> _onConnect(String url) async {
    await super._onConnect(url);
    try {
      // Disconnect previous transport if exists.
      _transport?.disconnect(1000, 'Reconnecting').ignore();

      // Create new transport.
      _transport = await _createTransport(url, config.headers)
        ..onReply = _onReply;

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
      await _onDisconnect((
        code: SpinifyConnectingCode.transportClosed,
        reason: 'Failed to connect'
      )).catchError((_) {});
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
  Future<void> disconnect(
          [int code = 0, String reason = 'Disconnect called']) =>
      _bucket.push(ClientEvent.disconnect, (code: code, reason: reason));

  @override
  Future<void> _onDisconnect(({int? code, String? reason}) arg) async {
    await _transport?.disconnect(1000, arg.reason);
    _transport = null;
    await super._onDisconnect(arg);
  }

  @override
  Future<void> _onClose() async {
    await _transport?.disconnect(1000, 'Client closing');
    _transport = null;
    await super._onClose();
  }
}

/// Base mixin for Spinify client ping-pong management.
base mixin SpinifyPingPongMixin
    on SpinifyBase, SpinifyStateMixin, SpinifyConnectionMixin {
  @protected
  @nonVirtual
  Timer? _pingTimer;

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
    assert(!_isClosed, 'Client is closed');
    assert(state.isConnected, 'Invalid state');
    if (state case SpinifyState$Connected(:Duration pingInterval)) {
      _pingTimer = Timer(
        pingInterval + config.serverPingDelay,
        () => disconnect(
          SpinifyConnectingCode.noPing,
          'No ping from server',
        ),
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
  Future<void> _onDisconnect(({int? code, String? reason}) arg) async {
    _tearDownPingTimer();
    await super._onDisconnect(arg);
  }

  @override
  Future<void> _onClose() async {
    _tearDownPingTimer();
    await super._onClose();
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
  SpinifyClientSubscription? getSubscription(String channel) {
    throw UnimplementedError();
  }

  @override
  SpinifyClientSubscription newSubscription(String channel,
      [SpinifySubscriptionConfig? config]) {
    throw UnimplementedError();
  }

  @override
  Future<void> removeSubscription(SpinifyClientSubscription subscription) {
    throw UnimplementedError();
  }
}

/// Base mixin for Spinify server subscription management.
base mixin SpinifyServerSubscriptionMixin on SpinifyBase {}

/// Base mixin for Spinify client publications management.
base mixin SpinifyPublicationsMixin on SpinifyBase {
  @override
  Future<void> publish(String channel, List<int> data) {
    throw UnimplementedError();
  }
}

/// Base mixin for Spinify client presence management.
base mixin SpinifyPresenceMixin on SpinifyBase {
  @override
  Future<SpinifyPresence> presence(String channel) {
    throw UnimplementedError();
  }

  @override
  Future<SpinifyPresenceStats> presenceStats(String channel) {
    throw UnimplementedError();
  }
}

/// Base mixin for Spinify client history management.
base mixin SpinifyHistoryMixin on SpinifyBase {
  @override
  Future<SpinifyHistory> history(String channel,
      {int? limit, SpinifyStreamPosition? since, bool? reverse}) {
    throw UnimplementedError();
  }
}

/// Base mixin for Spinify client RPC management.
base mixin SpinifyRPCMixin on SpinifyBase {
  @override
  Future<List<int>> rpc(String method, List<int> data) {
    throw UnimplementedError();
  }
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
  Spinify({SpinifyConfig? config, super.createTransport})
      : super(config: config ?? SpinifyConfig.byDefault());

  /// Create client and connect.
  ///
  /// {@macro spinify}
  factory Spinify.connect(
    String url, {
    SpinifyConfig? config,
    CreateSpinifyTransport? createTransport,
  }) =>
      Spinify(
        config: config,
        createTransport: createTransport,
      )..connect(url);

  @override
  SpinifyPushesStream get stream => throw UnimplementedError();
}
