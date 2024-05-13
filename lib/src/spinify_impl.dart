import 'dart:async';

import 'package:meta/meta.dart';

import 'model/channel_push.dart';
import 'model/command.dart';
import 'model/config.dart';
import 'model/history.dart';
import 'model/metrics.dart';
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
    config.logger?.call(
      3,
      'init',
      'Spinify client initialized',
      <String, Object?>{
        'config': config,
      },
    );
  }

  /// On connect to the server.
  @mustCallSuper
  Future<void> _onConnected() async {}

  @mustCallSuper
  Future<void> _onReply(SpinifyReply reply) async {
    config.logger?.call(
      0,
      'reply',
      'Reply ${reply.type}{id: ${reply.id}} received',
      <String, Object?>{
        'reply': reply,
      },
    );
  }

  /// On disconnect from the server.
  @mustCallSuper
  Future<void> _onDisconnected() async {
    config.logger?.call(
      2,
      'disconnected',
      'Disconnected',
      <String, Object?>{
        'state': state,
      },
    );
  }

  @override
  Future<void> close() async {
    config.logger?.call(
      3,
      'closed',
      'Closed',
      <String, Object?>{
        'state': state,
      },
    );
  }
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
  void _setState(SpinifyState state) {
    final previous = _state;
    _statesController.add(_state = state);
    config.logger?.call(
      2,
      'state_changed',
      'State changed from $previous to $state',
      <String, Object?>{
        'previous': previous,
        'state': state,
      },
    );
  }

  @override
  Future<void> _onConnected() async {
    await super._onConnected();
  }

  @override
  Future<void> _onDisconnected() async {
    await super._onDisconnected();
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
  final Map<int, ({SpinifyCommand command, Completer<SpinifyReply> completer})>
      _replies =
      <int, ({SpinifyCommand command, Completer<SpinifyReply> completer})>{};

  @override
  Future<void> send(List<int> data) => _sendCommandAsync(SpinifySendRequest(
        id: _getNextCommandId(),
        timestamp: DateTime.now(),
        data: data,
      ));

  Future<T> _sendCommand<T extends SpinifyReply>(SpinifyCommand command) async {
    config.logger?.call(
      0,
      'send_command_begin',
      'Command ${command.type}{id: ${command.id}} sent begin',
      <String, Object?>{
        'command': command,
      },
    );
    try {
      assert(command.id > -1, 'Command ID should be greater or equal to 0');
      assert(_replies[command.id] == null, 'Command ID should be unique');
      assert(_transport != null, 'Transport is not connected');
      assert(!state.isClosed, 'State is closed');
      final completer = Completer<T>();
      _replies[command.id] = (command: command, completer: completer);
      await _transport?.send(command); // await _sendCommandAsync(command);
      final result = await completer.future.timeout(config.timeout);
      config.logger?.call(
        2,
        'send_command_success',
        'Command ${command.type}{id: ${command.id}} sent successfully',
        <String, Object?>{
          'command': command,
          'result': result,
        },
      );
      return result;
    } on Object catch (error, stackTrace) {
      final tuple = _replies.remove(command.id);
      if (tuple != null && !tuple.completer.isCompleted) {
        tuple.completer.completeError(error, stackTrace);
        config.logger?.call(
          4,
          'send_command_error',
          'Error sending command ${command.type}{id: ${command.id}}',
          <String, Object?>{
            'command': command,
            'error': error,
            'stackTrace': stackTrace,
          },
        );
      }
      rethrow;
    }
  }

  Future<void> _sendCommandAsync(SpinifyCommand command) async {
    config.logger?.call(
      0,
      'send_command_async_begin',
      'Comand ${command.type}{id: ${command.id}} sent async begin',
      <String, Object?>{
        'command': command,
      },
    );
    try {
      assert(command.id > -1, 'Command ID should be greater or equal to 0');
      assert(_transport != null, 'Transport is not connected');
      assert(!state.isClosed, 'State is closed');
      await _transport?.send(command);
      config.logger?.call(
        2,
        'send_command_async_success',
        'Command sent ${command.type}{id: ${command.id}} async successfully',
        <String, Object?>{
          'command': command,
        },
      );
    } on Object catch (error, stackTrace) {
      config.logger?.call(
        4,
        'send_command_async_error',
        'Error sending command ${command.type}{id: ${command.id}} async',
        <String, Object?>{
          'command': command,
          'error': error,
          'stackTrace': stackTrace,
        },
      );
      rethrow;
    }
  }

  @override
  Future<void> _onReply(SpinifyReply reply) async {
    assert(reply.id > -1, 'Reply ID should be greater or equal to 0');
    if (reply.id case int id when id > 0) {
      final completer = _replies.remove(id)?.completer;
      assert(
        completer != null,
        'Reply completer not found',
      );
      assert(
        completer?.isCompleted == false,
        'Reply completer already completed',
      );
      completer?.complete(reply);
    }
    await super._onReply(reply);
  }

  @override
  Future<void> _onDisconnected() async {
    config.logger?.call(
      2,
      'disconnected',
      'Disconnected from server',
      <String, Object?>{},
    );
    late final error = StateError('Client is disconnected');
    late final stackTrace = StackTrace.current;
    for (final tuple in _replies.values) {
      if (tuple.completer.isCompleted) continue;
      tuple.completer.completeError(error);
      config.logger?.call(
        4,
        'disconnected_reply_error',
        'Reply for command ${tuple.command.type}{id: ${tuple.command.id}} '
            'error on disconnect',
        <String, Object?>{
          'command': tuple.command,
          'error': error,
          'stackTrace': stackTrace,
        },
      );
    }
    _replies.clear();
    await super._onDisconnected();
  }
}

/// Base mixin for Spinify client connection management (connect & disconnect).
base mixin SpinifyConnectionMixin
    on SpinifyBase, SpinifyCommandMixin, SpinifyStateMixin {
  /// Last connected URL.
  /// Used for reconnecting after connection lost.
  /// If null, then client is not connected or interractively disconnected.
  String? _reconnectUrl;
  Completer<void>? _readyCompleter;

  @protected
  @nonVirtual
  Timer? _refreshTimer;

  @override
  Future<void> connect(String url) async {
    if (state.url == url) return;
    final completer = _readyCompleter ??= Completer<void>();
    await disconnect();
    try {
      _setState(SpinifyState$Connecting(url: url));
      _reconnectUrl = url;

      // Create new transport.
      _transport = await _createTransport(url, config)
        ..onReply = _onReply
        ..onDisconnect = () => _onDisconnected().ignore();

      // Prepare connect request.
      final SpinifyConnectRequest request;
      {
        final token = await config.getToken?.call();
        assert(token == null || token.length > 5, 'Spinify JWT is too short');
        final payload = await config.getPayload?.call();
        request = SpinifyConnectRequest(
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

      final reply = await _sendCommand<SpinifyConnectResult>(request);
      _setState(SpinifyState$Connected(
        url: url,
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

      _setUpRefreshConnection();

      // Notify ready.
      if (!completer.isCompleted) completer.complete();
      _readyCompleter = null;

      await _onConnected();

      config.logger?.call(
        2,
        'connected',
        'Connected to server with $url successfully',
        <String, Object?>{
          'url': url,
          'request': request,
          'result': reply,
        },
      );
    } on Object catch (error, stackTrace) {
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
      _readyCompleter = null;
      config.logger?.call(
        5,
        'connect_error',
        'Error connecting to server $url',
        <String, Object?>{
          'url': url,
          'error': error,
          'stackTrace': stackTrace,
        },
      );
      rethrow;
    }
  }

  void _setUpRefreshConnection() {
    _refreshTimer?.cancel();
    if (state
        case SpinifyState$Connected(
          :String url,
          :bool expires,
          :DateTime? ttl,
          :String? node,
          :Duration? pingInterval,
          :bool? sendPong,
          :String? session,
          :List<int>? data,
        ) when expires && ttl != null) {
      final duration = ttl.difference(DateTime.now()) - config.timeout;
      if (duration < Duration.zero) {
        config.logger?.call(
          4,
          'refresh_connection_cancelled',
          'Spinify token TTL is too short for refresh connection',
          <String, Object?>{
            'url': url,
            'duration': duration,
            'ttl': ttl,
          },
        );
        assert(false, 'Token TTL is too short');
        return;
      }
      _refreshTimer = Timer(duration, () async {
        if (!state.isConnected) return;
        final token = await config.getToken?.call();
        if (token == null || token.isEmpty) {
          assert(token == null || token.length > 5, 'Spinify JWT is too short');
          config.logger?.call(
            4,
            'refresh_connection_cancelled',
            'Spinify JWT is empty or too short for refresh connection',
            <String, Object?>{
              'url': url,
              'token': token,
            },
          );
          return;
        }
        final request = SpinifyRefreshRequest(
          id: _getNextCommandId(),
          timestamp: DateTime.now(),
          token: token,
        );
        final SpinifyRefreshResult result;
        try {
          result = await _sendCommand<SpinifyRefreshResult>(request);
        } on Object catch (error, stackTrace) {
          config.logger?.call(
            5,
            'refresh_connection_error',
            'Error refreshing connection',
            <String, Object?>{
              'url': url,
              'command': request,
              'error': error,
              'stackTrace': stackTrace,
            },
          );
          return;
        }
        _setState(SpinifyState$Connected(
          url: url,
          client: result.client,
          version: result.version,
          expires: result.expires,
          ttl: result.ttl,
          node: node,
          pingInterval: pingInterval,
          sendPong: sendPong,
          session: session,
          data: data,
        ));
        _setUpRefreshConnection();
        config.logger?.call(
          2,
          'refresh_connection_success',
          'Successfully refreshed connection to $url',
          <String, Object?>{
            'request': request,
            'result': result,
          },
        );
      });
    }
  }

  @override
  Future<void> ready() async {
    if (state.isConnected) return;
    return (_readyCompleter ??= Completer<void>()).future;
  }

  @override
  Future<void> disconnect() async {
    _reconnectUrl = null;
    if (state.isDisconnected) return Future.value();
    await _transport?.disconnect(1000, 'Client disconnecting');
    await _onDisconnected();
  }

  @override
  Future<void> _onDisconnected() async {
    _refreshTimer?.cancel();
    _transport = null;
    await super._onDisconnected();
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
          if (state case SpinifyState$Connected(:String url)) {
            config.logger?.call(
              4,
              'no_pong_reconnect',
              'No pong from server - reconnecting',
              <String, Object?>{
                'url': url,
                'pingInterval': pingInterval,
                'serverPingDelay': config.serverPingDelay,
              },
            );
            connect(url);
          }
          /* disconnect(
            SpinifyConnectingCode.noPing,
            'No ping from server',
          ); */
        },
      );
    }
  }

  @override
  Future<void> _onConnected() async {
    _tearDownPingTimer();
    await super._onConnected();
    _restartPingTimer();
  }

  @override
  Future<void> _onReply(SpinifyReply reply) async {
    if (reply is SpinifyServerPing) {
      final command = SpinifyPingRequest(timestamp: DateTime.now());
      await _sendCommandAsync(command);
      config.logger?.call(
        0,
        'server_ping_received',
        'Ping from server received, pong sent',
        <String, Object?>{
          'ping': reply,
          'pong': command,
        },
      );
      _restartPingTimer();
    }
    await super._onReply(reply);
  }

  @override
  Future<void> _onDisconnected() async {
    _tearDownPingTimer();
    await super._onDisconnected();
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
