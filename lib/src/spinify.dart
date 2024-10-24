import 'dart:async';
import 'dart:collection';

import 'model/annotations.dart';
import 'model/channel_event.dart';
import 'model/channel_events.dart';
import 'model/client_info.dart';
import 'model/command.dart';
import 'model/config.dart';
import 'model/constant.dart';
import 'model/exception.dart';
import 'model/history.dart';
import 'model/metric.dart';
import 'model/presence_stats.dart';
import 'model/reply.dart';
import 'model/state.dart';
import 'model/states_stream.dart';
import 'model/stream_position.dart';
import 'model/subscription_config.dart';
import 'model/transport_interface.dart';
import 'spinify_interface.dart';
import 'subscription_interface.dart';
import 'web_socket_stub.dart'
    // ignore: uri_does_not_exist
    if (dart.library.js_interop) 'web_socket_js.dart'
    // ignore: uri_does_not_exist
    if (dart.library.io) 'web_socket_vm.dart';

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
final class Spinify implements ISpinify {
  /// Create a new Spinify client.
  ///
  /// {@macro spinify}
  @safe
  Spinify({SpinifyConfig? config})
      : config = config ?? SpinifyConfig.byDefault() {
    /// Client initialization (from constructor).
    _init();
  }

  /// Create client and connect.
  ///
  /// {@macro spinify}
  @safe
  factory Spinify.connect(String url, {SpinifyConfig? config}) =>
      Spinify(config: config)..connect(url).ignore();

  /// Spinify config.
  @safe
  @override
  final SpinifyConfig config;

  @safe
  @override
  SpinifyMetrics get metrics => _metrics.freeze();

  WebSocket? _transport;

  /// Internal mutable metrics. Also it's container for Spinify's state.
  final SpinifyMetrics$Mutable _metrics = SpinifyMetrics$Mutable();

  @safe
  @override
  SpinifyState get state => _metrics.state;

  @safe
  @override
  bool get isClosed => _metrics.state.isClosed;

  @safe
  @override
  late final SpinifyStatesStream states =
      SpinifyStatesStream(_statesController.stream);

  @safe
  final StreamController<SpinifyState> _statesController =
      StreamController<SpinifyState>.broadcast();

  @override
  late final SpinifyChannelEvents<SpinifyChannelEvent> stream =
      SpinifyChannelEvents<SpinifyChannelEvent>(_eventController.stream);
  final StreamController<SpinifyChannelEvent> _eventController =
      StreamController<SpinifyChannelEvent>.broadcast();

  Completer<void>? _readyCompleter;
  Timer? _refreshTimer;
  Timer? _reconnectTimer;
  Timer? _healthTimer;

  /// Registry of client subscriptions.
  final Map<String, SpinifyClientSubscription> _clientSubscriptionRegistry =
      <String, SpinifyClientSubscription>{};

  /// Registry of server subscriptions.
  final Map<String, SpinifyServerSubscription> _serverSubscriptionRegistry =
      <String, SpinifyServerSubscription>{};

  @override
  ({
    Map<String, SpinifyClientSubscription> client,
    Map<String, SpinifyServerSubscription> server
  }) get subscriptions => (
        client: UnmodifiableMapView<String, SpinifyClientSubscription>(
          _clientSubscriptionRegistry,
        ),
        server: UnmodifiableMapView<String, SpinifyServerSubscription>(
          _serverSubscriptionRegistry,
        ),
      );

  /// Hash map of pending replies.
  final Map<int, _PendingReply> _replies = <int, _PendingReply>{};

  /// Log an event with the given [level], [event], [message] and [context].
  @safe
  void _log(
    SpinifyLogLevel level,
    String event,
    String message,
    Map<String, Object?> context,
  ) {
    try {
      config.logger?.call(level, event, message, context);
    } on Object {/* ignore */}
  }

  /// Set a new state and notify listeners via [states].
  @safe
  void _setState(SpinifyState state) {
    if (isClosed) return;
    final previous = _metrics.state;
    _statesController.add(_metrics.state = state);
    _log(
      const SpinifyLogLevel.config(),
      'state_changed',
      'State changed from $previous to $state',
      <String, Object?>{
        'previous': previous,
        'state': state,
      },
    );
  }

  /// Counter for command messages.
  @safe
  int _getNextCommandId() {
    if (_metrics.commandId == kMaxInt) _metrics.commandId = 1;
    return _metrics.commandId++;
  }

  // --- Init --- //

  /// Initialization from constructor
  @safe
  void _init() {
    _setUpHealthCheckTimer();
    _log(
      const SpinifyLogLevel.info(),
      'init',
      'Spinify client initialized',
      <String, Object?>{
        'config': config,
      },
    );
  }

  // --- Health checks --- //

  /// Set up health check timer.
  @safe
  void _setUpHealthCheckTimer() {
    _tearDownHealthCheckTimer();

    void warning(String message) => _log(
          const SpinifyLogLevel.warning(),
          'health_check_error',
          message,
          <String, Object?>{},
        );

    _healthTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (_statesController.isClosed) {
          warning('Health check failed: states controller is closed');
        }
        if (_eventController.isClosed) {
          warning('Health check failed: event controller is closed');
        }
        switch (state) {
          case SpinifyState$Disconnected state:
            if (state.temporary && _reconnectTimer == null) {
              warning('Health check failed: no reconnect timer set');
            }
            if (state.temporary && _metrics.reconnectUrl == null) {
              warning('Health check failed: no reconnect URL set');
            }
            if (_refreshTimer != null) {
              warning(
                  'Health check failed: refresh timer set but not connected');
            }
          case SpinifyState$Connecting _:
            if (_reconnectTimer == null) {
              warning('Health check failed: no reconnect timer set');
            }
            if (_refreshTimer == null) {
              warning('Health check failed: no refresh timer set');
            }
          case SpinifyState$Connected _:
            if (_refreshTimer == null) {
              warning('Health check failed: no refresh timer set');
            }
          case SpinifyState$Closed _:
            warning('Health check failed: health check should be stopped');
        }
      },
    );
  }

  /// Tear down health check timer.
  @safe
  void _tearDownHealthCheckTimer() {
    _healthTimer?.cancel();
    _healthTimer = null;
  }

  /// Set up refresh connection timer.
  @safe
  void _setUpRefreshConnection() {
    _tearDownRefreshConnection();
  }

  /// Tear down refresh connection timer.
  @safe
  void _tearDownRefreshConnection() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Set up reconnect timer.
  @safe
  void _setUpReconnectTimer() {
    _tearDownReconnectTimer();
  }

  /// Tear down reconnect timer.
  @safe
  void _tearDownReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  // --- Ready --- //

  @unsafe
  @override
  @Throws([SpinifyConnectionException])
  Future<void> ready() async {
    const error = SpinifyConnectionException(
      message: 'Connection is closed permanently',
    );
    if (state.isConnected) return;
    if (state.isClosed) throw error;
    try {
      await (_readyCompleter ??= Completer<void>()).future;
    } on SpinifyConnectionException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        SpinifyConnectionException(
          message: 'Failed to wait for connection',
          error: error,
        ),
        stackTrace,
      );
    }
  }

  /// Plan to do action when client is connected.
  @unsafe
  Future<T> _doOnReady<T>(Future<T> Function() action) => switch (state) {
        SpinifyState$Connected _ => action(),
        SpinifyState$Connecting _ => ready().then<T>((_) => action()),
        SpinifyState$Disconnected _ => Future.error(
            const SpinifyConnectionException(message: 'Disconnected')),
        SpinifyState$Closed _ =>
          Future.error(const SpinifyConnectionException(message: 'Closed')),
      };

  // --- Connection --- //

  Future<WebSocket> _webSocketConnect({
    required String url,
    Map<String, String>? headers,
    Iterable<String>? protocols,
  }) =>
      (config.transportBuilder ?? $webSocketConnect)(
        url: url,
        headers: headers,
        protocols: protocols,
      );

  @unsafe
  @override
  @Throws([SpinifyConnectionException])
  Future<void> connect(String url) async {
    try {
      await _interactiveConnect(url);
    } on SpinifyConnectionException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        SpinifyConnectionException(
          message: 'Failed to connect to server',
          error: error,
        ),
        stackTrace,
      );
    }
  }

  /// User initiated connect.
  @unsafe
  Future<void> _interactiveConnect(String url) async {
    if (state.isConnected || state.isConnecting) await _interactiveDisconnect();
    _setUpReconnectTimer();
    await _internalReconnect(url);
  }

  /// Library initiated connect.
  @unsafe
  Future<void> _internalReconnect(String url) async {
    assert(state.isDisconnected, 'State should be disconnected');
    final completer = _readyCompleter = switch (_readyCompleter) {
      Completer<void> value when !value.isCompleted => value,
      _ => Completer<void>(),
    };
    _setState(SpinifyState$Connecting(url: _metrics.reconnectUrl = url));
    assert(state.isConnecting, 'State should be connecting');
    // TODO: Create a new transport

    // Prepare connect request.
    final SpinifyConnectRequest request;
    {
      final token = await config.getToken?.call();
      final payload = await config.getPayload?.call();
      final id = _getNextCommandId();
      final now = DateTime.now();
      request = SpinifyConnectRequest(
        id: id,
        timestamp: now,
        token: token,
        data: payload,
        subs: <String, SpinifySubscribeRequest>{
          for (final sub in _serverSubscriptionRegistry.values)
            sub.channel: SpinifySubscribeRequest(
              id: id,
              timestamp: now,
              channel: sub.channel,
              recover: sub.recoverable,
              epoch: sub.epoch,
              offset: sub.offset,
              token: null,
              data: null,
              positioned: null,
              recoverable: null,
              joinLeave: null,
            ),
        },
        name: config.client.name,
        version: config.client.version,
      );
    }

    // ...

    _setUpRefreshConnection();
  }

  // --- Disconnection --- //

  @safe
  @override
  Future<void> disconnect() => _interactiveDisconnect();

  /// User initiated disconnect.
  @safe
  Future<void> _interactiveDisconnect() async {
    _tearDownReconnectTimer();
    _metrics.reconnectUrl = null;
    _internalDisconnect(
      code: 0,
      reason: 'disconnect interactively called by client',
      reconnect: false,
    );
  }

  /// Library initiated disconnect.
  @safe
  void _internalDisconnect({
    required int code,
    required String reason,
    required bool reconnect,
  }) {
    try {
      // Close all pending replies with error.
      const error = SpinifyReplyException(
        replyCode: 0,
        replyMessage: 'Client is disconnected',
        temporary: true,
      );
      late final stackTrace = StackTrace.current;
      for (final completer in _replies.values) {
        if (completer.isCompleted) continue;
        completer.completeError(error, stackTrace);
        _log(
          const SpinifyLogLevel.warning(),
          'disconnected_reply_error',
          'Reply for command '
              '${completer.command.type}{id: ${completer.command.id}} '
              'error on disconnect',
          <String, Object?>{
            'command': completer.command,
            'error': error,
            'stackTrace': stackTrace,
          },
        );
      }
      _replies.clear();

      // Complete ready completer with error,
      // if we still waiting for connection.
      if (_readyCompleter case Completer<void> c when !c.isCompleted) {
        c.completeError(error, stackTrace);
      }
    } on Object catch (error, stackTrace) {
      _log(
        const SpinifyLogLevel.warning(),
        'disconnected_error',
        'Error on disconnect',
        <String, Object?>{
          'error': error,
          'stackTrace': stackTrace,
        },
      );
    } finally {
      _setState(SpinifyState$Disconnected(temporary: reconnect));
      _log(
        const SpinifyLogLevel.config(),
        'disconnected',
        'Disconnected from server ${reconnect ? 'temporarily' : 'permanent'}',
        <String, Object?>{
          'temporary': reconnect,
        },
      );
    }
  }

  // --- Close --- //

  @safe
  @override
  Future<void> close() async {
    if (state.isClosed) return;
    try {
      _tearDownHealthCheckTimer();
      _internalDisconnect(
        code: 0,
        reason: 'close interactively called by client',
        reconnect: false,
      );
      _setState(SpinifyState$Closed());
    } on Object {/* ignore */} finally {
      _statesController.close().ignore();
      _eventController.close().ignore();
      _log(
        const SpinifyLogLevel.info(),
        'closed',
        'Closed',
        <String, Object?>{
          'state': state,
        },
      );
    }
  }

  // --- Send --- //

  @unsafe
  @Throws([SpinifySendException])
  Future<void> _sendCommandAsync(SpinifyCommand command) async {
    _log(
      const SpinifyLogLevel.debug(),
      'send_command_async_begin',
      'Comand ${command.type}{id: ${command.id}} sent async begin',
      <String, Object?>{
        'command': command,
      },
    );
    try {
      // coverage:ignore-start
      assert(command.id > -1, 'Command ID should be greater or equal to 0');
      assert(_transport != null, 'Transport is not connected');
      assert(!state.isClosed, 'State is closed');
      // coverage:ignore-end
      // TODO: Encode command to binary format.
      // TODO: Check that transport is not closed and exists.
      // TODO: Send command to the server.
      //await _transport?.send(command);
      _log(
        const SpinifyLogLevel.config(),
        'send_command_async_success',
        'Command sent ${command.type}{id: ${command.id}} async successfully',
        <String, Object?>{
          'command': command,
        },
      );
    } on Object catch (error, stackTrace) {
      _log(
        const SpinifyLogLevel.warning(),
        'send_command_async_error',
        'Error sending command ${command.type}{id: ${command.id}} async',
        <String, Object?>{
          'command': command,
          'error': error,
          'stackTrace': stackTrace,
        },
      );
      Error.throwWithStackTrace(
        SpinifySendException(
          message: 'Failed to send command ${command.type}{id: ${command.id}}',
        ),
        stackTrace,
      );
    }
  }

  @unsafe
  @override
  @Throws([SpinifySendException])
  Future<void> send(List<int> data) async {
    try {
      await _doOnReady(() => _sendCommandAsync(
            SpinifySendRequest(
              timestamp: DateTime.now(),
              data: data,
            ),
          ));
    } on SpinifySendException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(SpinifySendException(error: error), stackTrace);
    }
  }

  // --- Remote Procedure Call --- //

  @override
  Future<List<int>> rpc(String method, [List<int>? data]) {
    throw UnimplementedError();
  }

  // --- Subscriptions and Channels --- //

  @safe
  @override
  SpinifySubscription? getSubscription(String channel) =>
      _clientSubscriptionRegistry[channel] ??
      _serverSubscriptionRegistry[channel];

  @safe
  @override
  SpinifyClientSubscription? getClientSubscription(String channel) =>
      _clientSubscriptionRegistry[channel];

  @safe
  @override
  SpinifyServerSubscription? getServerSubscription(String channel) =>
      _serverSubscriptionRegistry[channel];

  @override
  SpinifyClientSubscription newSubscription(
    String channel, {
    SpinifySubscriptionConfig? config,
    bool subscribe = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> removeSubscription(SpinifyClientSubscription subscription) {
    throw UnimplementedError();
  }

  // --- Publish --- //

  @override
  Future<void> publish(String channel, List<int> data) {
    throw UnimplementedError();
  }

  // --- Presence --- //

  @override
  Future<Map<String, SpinifyClientInfo>> presence(String channel) {
    throw UnimplementedError();
  }

  @override
  Future<SpinifyPresenceStats> presenceStats(String channel) {
    throw UnimplementedError();
  }

  // --- History --- //

  @override
  Future<SpinifyHistory> history(
    String channel, {
    int? limit,
    SpinifyStreamPosition? since,
    bool? reverse,
  }) {
    throw UnimplementedError();
  }

  // --- Replies --- //

  /// Called when [SpinifyReply] received from the server.
  @safe
  @sideEffect
  Future<void> _onReply(SpinifyReply reply) async {
    try {
      // coverage:ignore-start
      if (reply.id < 0 || reply.id > _metrics.commandId) {
        assert(
            reply.id >= 0 && reply.id <= _metrics.commandId,
            'Reply ID should be greater or equal to 0 '
            'and less or equal than command ID');
        return;
      }
      // coverage:ignore-end
      if (reply.isResult) {
        // If reply is a result then find pending reply and complete it.
        if (reply.id case int id when id > 0) {
          final completer = _replies.remove(id);
          // coverage:ignore-start
          if (completer == null || completer.isCompleted) {
            assert(
              completer != null,
              'Reply completer not found',
            );
            assert(
              completer?.isCompleted == false,
              'Reply completer already completed',
            );
            return;
          }
          // coverage:ignore-end
          if (reply is SpinifyErrorResult) {
            completer.completeError(
              SpinifyReplyException(
                replyCode: reply.code,
                replyMessage: reply.message,
                temporary: reply.temporary,
              ),
              StackTrace.current,
            );
          } else {
            completer.complete(reply);
          }
        }
      } else if (reply is SpinifyPush) {
        switch (reply.event) {
          case SpinifyDisconnect disconnect:
            _internalDisconnect(
              code: disconnect.code,
              reason: disconnect.reason,
              reconnect: disconnect.reconnect,
            );
          default:
          // TODO: Handle other push events.
        }
      }

      _log(
        const SpinifyLogLevel.debug(),
        'reply',
        'Reply ${reply.type}{id: ${reply.id}} received',
        <String, Object?>{
          'reply': reply,
        },
      );
    } on Object catch (error, stackTrace) {
      _log(
        const SpinifyLogLevel.warning(),
        'reply_error',
        'Error processing reply',
        <String, Object?>{
          'reply': reply,
          'error': error,
          'stackTrace': stackTrace,
        },
      );
    }
  }
}

/// Pending reply.
class _PendingReply {
  _PendingReply(this.command) : _completer = Completer<SpinifyReply>();

  final SpinifyCommand command;
  final Completer<SpinifyReply> _completer;

  bool get isCompleted => _completer.isCompleted;

  void complete(SpinifyReply reply) => _completer.complete(reply);

  void completeError(SpinifyReplyException error, StackTrace stackTrace) =>
      _completer.completeError(error, stackTrace);
}
