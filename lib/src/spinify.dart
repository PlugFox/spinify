import 'dart:async';
import 'dart:collection';

import 'model/annotations.dart';
import 'model/channel_event.dart';
import 'model/channel_events.dart';
import 'model/client_info.dart';
import 'model/codec.dart';
import 'model/codes.dart';
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
import 'protobuf/protobuf_codec.dart';
import 'spinify_interface.dart';
import 'subscription_interface.dart';
import 'util/backoff.dart';
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
      : config = config ?? SpinifyConfig.byDefault(),
        _codec = config?.codec ?? SpinifyProtobufCodec() {
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

  /// Codec to encode and decode messages for the [_transport].
  final SpinifyCodec _codec;

  /// Current WebSocket transport.
  WebSocket? _transport;
  StreamSubscription<SpinifyReply>? _replySubscription;

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
      StreamController<SpinifyState>.broadcast(sync: true);

  @override
  late final SpinifyChannelEvents<SpinifyChannelEvent> stream =
      SpinifyChannelEvents<SpinifyChannelEvent>(_eventController.stream);
  final StreamController<SpinifyChannelEvent> _eventController =
      StreamController<SpinifyChannelEvent>.broadcast(sync: true);

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
    if (isClosed) return; // Client is closed, do not notify about states.
    final prev = _metrics.state, next = state;
    if (prev.type == next.type) {
      // Should we notify about the same state?
      switch ((prev, next)) {
        case (SpinifyState$Connecting prev, SpinifyState$Connecting next):
          if (prev.url == next.url) return; // The same
        case (SpinifyState$Disconnected prev, SpinifyState$Disconnected next):
          if (prev.temporary == next.temporary) return; // The same
        case (SpinifyState$Closed _, SpinifyState$Closed _):
          return; // Do not notify about closed states changes.
        case (SpinifyState$Connected _, SpinifyState$Connected _):
          break; // Always notify about connected states changes.
        default:
          break; // Notify about other states changes.
      }
    }
    _statesController.add(_metrics.state = next);
    _log(
      const SpinifyLogLevel.config(),
      'state_changed',
      'State changed from $prev to $next',
      <String, Object?>{
        'prev': prev,
        'next': next,
        'state': next,
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
      const Duration(seconds: 15),
      (_) {
        if (_statesController.isClosed) {
          warning('Health check failed: states controller is closed');
        }
        if (_eventController.isClosed) {
          warning('Health check failed: event controller is closed');
        }
        switch (state) {
          case SpinifyState$Disconnected state:
            if (state.temporary) {
              if (_metrics.reconnectUrl == null) {
                warning('Health check failed: no reconnect URL set');
                _setState(SpinifyState$Disconnected(temporary: false));
              } else if (_reconnectTimer == null) {
                warning('Health check failed: no reconnect timer set');
                _setUpReconnectTimer();
              }
            }
            if (_refreshTimer != null) {
              warning(
                  'Health check failed: refresh timer set but not connected');
            }
            if (_transport != null || _replySubscription != null) {
              warning('Health check failed: transport is not closed');
              _internalDisconnect(
                code: const SpinifyDisconnectCode.abnormalClosure(),
                reason: 'abnormal closure',
                reconnect: false,
              );
            }
          case SpinifyState$Connecting _:
            if (_refreshTimer != null) {
              warning('Health check failed: refresh timer set during connect');
            }
          case SpinifyState$Connected _:
            if (_refreshTimer == null) {
              warning('Health check failed: no refresh timer set');
              _setUpRefreshConnection();
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
    // TODO: Implement refresh connection timer.
    // Mike Matiunin <plugfox@gmail.com>, 25 October 2024
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
    final lastUrl = _metrics.reconnectUrl;
    if (lastUrl == null) return;
    final attempt = _metrics.reconnectAttempts ?? 0;
    final delay = Backoff.nextDelay(
      attempt,
      config.connectionRetryInterval.min.inMilliseconds,
      config.connectionRetryInterval.max.inMilliseconds,
    );
    _metrics.nextReconnectAt = DateTime.now().add(delay);
    config.logger?.call(
      const SpinifyLogLevel.debug(),
      'reconnect_delayed',
      'Setting up reconnect timer to $lastUrl '
          'after ${delay.inMilliseconds} ms.',
      {
        'url': lastUrl,
        'delay': delay,
        'attempt': attempt,
      },
    );
    _reconnectTimer = Timer(
      delay,
      () {
        //_nextReconnectionAttempt = null;
        if (!state.isDisconnected) return;
        _metrics.reconnectAttempts = attempt + 1;
        config.logger?.call(
          const SpinifyLogLevel.config(),
          'reconnect_attempt',
          'Reconnecting to $lastUrl after ${delay.inMilliseconds} ms.',
          {
            'url': lastUrl,
            'delay': delay,
          },
        );
        try {
          _internalReconnect(lastUrl);
        } on Object catch (error, stackTrace) {
          _log(
            const SpinifyLogLevel.error(),
            'reconnect_error',
            'Error reconnecting to $lastUrl',
            <String, Object?>{
              'url': lastUrl,
              'error': error,
              'stackTrace': stackTrace,
            },
          );
        }
      },
    );
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
            const SpinifyConnectionException(message: 'Disconnected'),
            StackTrace.current,
          ),
        SpinifyState$Closed _ => Future.error(
            const SpinifyConnectionException(message: 'Closed'),
            StackTrace.current,
          ),
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
    if (isClosed)
      throw const SpinifyConnectionException(
        message: 'Client is closed permanently',
      );
    if (state.isConnected || state.isConnecting) await _interactiveDisconnect();
    _setUpReconnectTimer();
    await _internalReconnect(url);
  }

  /// Library initiated connect.
  @unsafe
  Future<void> _internalReconnect(String url) async {
    final readyCompleter = _readyCompleter = switch (_readyCompleter) {
      Completer<void> value when !value.isCompleted => value,
      _ => Completer<void>(),
    };
    if (state.isConnected || state.isConnecting) {
      _internalDisconnect(
        code: const SpinifyDisconnectCode.normalClosure(),
        reason: 'normal closure',
        reconnect: false,
      );
    }
    try {
      if (!state.isDisconnected) {
        _log(
          const SpinifyLogLevel.warning(),
          'reconnect_error',
          'Failed to reconnect: state is not disconnected',
          <String, Object?>{
            'state': state,
          },
        );
        assert(
          false,
          'State should be disconnected',
        );
        return;
      }
      assert(
        _transport == null,
        'Transport should be null',
      );
      assert(
        _replySubscription == null,
        'Reply subscription should be null',
      );
      _setState(SpinifyState$Connecting(url: _metrics.reconnectUrl = url));
      assert(state.isConnecting, 'State should be connecting');

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

      // Create a new transport
      final ws = _transport = await _webSocketConnect(
        url: url,
        headers: config.headers,
        protocols: <String>[_codec.protocol],
      );

      // Create handler for connect reply.
      final connectResultCompleter = Completer<SpinifyConnectResult>();

      // ignore: omit_local_variable_types
      void Function(SpinifyReply reply) handleReply = (reply) {
        if (connectResultCompleter.isCompleted) {
          _log(
            const SpinifyLogLevel.warning(),
            'connect_result_error',
            'Connect result completer is already completed',
            <String, Object?>{
              'reply': reply,
            },
          );
        } else if (reply is SpinifyConnectResult) {
          connectResultCompleter.complete(reply);
        } else if (reply is SpinifyErrorResult) {
          connectResultCompleter.completeError(reply);
        } else {
          connectResultCompleter.completeError(
            const SpinifyConnectionException(
              message: 'Unexpected reply received',
            ),
          );
        }
      };

      void handleDone() {
        assert(() {
          if (!identical(ws, _transport)) {
            _log(
              const SpinifyLogLevel.warning(),
              'transport_closed_error',
              'Transport closed on different and not active transport',
              <String, Object?>{
                'transport': ws,
              },
            );
          }
          return true;
        }(), '...');
        var WebSocket(:int? closeCode, :String? closeReason) = ws;
        final close = SpinifyDisconnectCode.normalize(closeCode, closeReason);
        _log(
          const SpinifyLogLevel.transport(),
          'transport_disconnect',
          'Transport disconnected '
              '${close.reconnect ? 'temporarily' : 'permanently'} '
              'with reason: ${close.reason}',
          <String, Object?>{
            'code': close.code,
            'reason': close.reason,
            'reconnect': close.reconnect,
          },
        );
        _internalDisconnect(
          code: close.code,
          reason: close.reason,
          reconnect: close.reconnect,
        );
      }

      _replySubscription =
          ws.stream.transform<SpinifyReply>(StreamTransformer.fromHandlers(
        handleData: (data, sink) {
          _metrics
            ..bytesReceived += data.length
            ..chunksReceived += 1;
          for (final reply in _codec.decoder.convert(data)) {
            _metrics.repliesDecoded += 1;
            sink.add(reply);
          }
        },
      )).listen(
        (reply) {
          assert(() {
            if (!identical(ws, _transport)) {
              _log(
                const SpinifyLogLevel.warning(),
                'wrong_transport_error',
                'Reply received on different and not active transport',
                <String, Object?>{
                  'transport': ws,
                  'reply': reply,
                },
              );
            }
            return true;
          }(), '...');

          handleReply(reply); // Handle replies
        },
        onDone: handleDone,
        onError: (Object error, StackTrace stackTrace) {
          _log(
            const SpinifyLogLevel.warning(),
            'reply_error',
            'Error receiving reply',
            <String, Object?>{
              'error': error,
              'stackTrace': stackTrace,
            },
          );
        },
        cancelOnError: false,
      );

      await _sendCommandAsync(request);
      final result = await connectResultCompleter.future;

      if (!state.isConnecting) {
        throw const SpinifyConnectionException(
          message: 'Connection is not in connecting state',
        );
      } else if (!identical(ws, _transport)) {
        throw const SpinifyConnectionException(
          message: 'Transport is not the same as created',
        );
      }

      _setState(SpinifyState$Connected(
        url: url,
        client: result.client,
        version: result.version,
        expires: result.expires,
        ttl: result.ttl,
        node: result.node,
        pingInterval: result.pingInterval,
        sendPong: result.sendPong,
        session: result.session,
        data: result.data,
      ));

      handleReply = _onReply; // Switch to normal reply handler

      _setUpRefreshConnection();

      // Notify ready.
      if (readyCompleter.isCompleted) {
        throw const SpinifyConnectionException(
          message: 'Ready completer is already completed. Why so?',
        );
      } else {
        readyCompleter.complete();
        _readyCompleter = null;
      }

      _metrics.lastConnectAt = DateTime.now();
      _metrics.connects++;

      _log(
        const SpinifyLogLevel.config(),
        'connected',
        'Connected to server with $url successfully',
        <String, Object?>{
          'url': url,
          'request': request,
          'result': result,
        },
      );
    } on Object catch ($error, stackTrace) {
      final SpinifyConnectionException error;
      if ($error is SpinifyConnectionException) {
        error = $error;
      } else {
        error = SpinifyConnectionException(
          message: 'Error connecting to server $url',
          error: $error,
        );
      }
      if (!readyCompleter.isCompleted)
        readyCompleter.completeError(error, stackTrace);
      _readyCompleter = null;
      _log(
        const SpinifyLogLevel.error(),
        'connect_error',
        'Error connecting to server $url',
        <String, Object?>{
          'url': url,
          'error': error,
          'stackTrace': stackTrace,
        },
      );
      _transport?.close();

      switch ($error) {
        case SpinifyErrorResult result:
          if (result.code == 109) {
            // Token expired error.
            _setUpReconnectTimer(); // Retry resubscribe
          } else if (result.temporary) {
            // Temporary error.
            _setUpReconnectTimer(); // Retry resubscribe
          } else {
            // Disable resubscribe timer on permanent errors.
            _setState(SpinifyState$Disconnected(temporary: false));
          }
        case SpinifyConnectionException _:
          _setUpReconnectTimer(); // Some spinify exception - retry resubscribe
        default:
          _setUpReconnectTimer(); // Unknown error - retry resubscribe
      }

      Error.throwWithStackTrace(error, stackTrace);
    }
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
      code: const SpinifyDisconnectCode.normalClosure(),
      reason: 'normal closure',
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
      _tearDownRefreshConnection();

      // Unsuscribe from reply messages.
      // To ignore last messages and done event from transport.
      _replySubscription?.cancel().ignore();
      _replySubscription = null;
      // Close transport.
      _transport?.close(code, reason);
      _transport = null;

      // Update metrics.
      _metrics.lastDisconnectAt = DateTime.now();
      _metrics.disconnects++;

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

      // Reconnect if [reconnect] is true and we have reconnect URL.
      if (reconnect && _metrics.reconnectUrl != null) _setUpReconnectTimer();
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
        code: const SpinifyDisconnectCode.normalClosure(),
        reason: 'normal closure',
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
      final bytes = _codec.encoder.convert(command);
      _metrics.commandsEncoded += 1;
      if (_transport == null)
        throw const SpinifySendException(message: 'Transport is not connected');
      _transport?.add(bytes);
      _metrics
        ..bytesSent += bytes.length
        ..chunksSent += 1;
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
      if (error is SpinifySendException)
        rethrow;
      else
        Error.throwWithStackTrace(
          SpinifySendException(
            message:
                'Failed to send command ${command.type}{id: ${command.id}}',
          ),
          stackTrace,
        );
    }
  }

  @unsafe
  @Throws([SpinifySendException])
  Future<R> _sendCommand<R extends SpinifyReply>(SpinifyCommand command) async {
    _log(
      const SpinifyLogLevel.debug(),
      'send_command_begin',
      'Command ${command.type}{id: ${command.id}} sent begin',
      <String, Object?>{
        'command': command,
      },
    );
    try {
      // coverage:ignore-start
      assert(command.id > -1, 'Command ID should be greater or equal to 0');
      assert(_replies[command.id] == null, 'Command ID should be unique');
      assert(_transport != null, 'Transport is not connected');
      assert(!state.isClosed, 'State is closed');
      // coverage:ignore-end
      final bytes = _codec.encoder.convert(command);
      _metrics.commandsEncoded += 1;
      final pr = _replies[command.id] = _PendingReply<R>(command);
      if (_transport == null)
        throw const SpinifySendException(message: 'Transport is not connected');
      _transport?.add(bytes);
      _metrics
        ..bytesSent += bytes.length
        ..chunksSent += 1;
      final result = await pr.future.timeout(config.timeout);
      _log(
        const SpinifyLogLevel.config(),
        'send_command_success',
        'Command ${command.type}{id: ${command.id}} sent successfully',
        <String, Object?>{
          'command': command,
          'result': result,
        },
      );
      return result;
    } on Object catch (error, stackTrace) {
      if (_replies.remove(command.id) case _PendingReply pr
          when !pr.isCompleted) {
        pr.completeError(
          SpinifyReplyException(
            replyCode: 0,
            replyMessage: 'Failed to send command',
            temporary: true,
            error: error,
          ),
          stackTrace,
        );
      }
      _log(
        const SpinifyLogLevel.warning(),
        'send_command_error',
        'Error sending command ${command.type}{id: ${command.id}}',
        <String, Object?>{
          'command': command,
          'error': error,
          'stackTrace': stackTrace,
        },
      );
      if (error is SpinifySendException)
        rethrow;
      else
        Error.throwWithStackTrace(
          SpinifySendException(
            message:
                'Failed to send command ${command.type}{id: ${command.id}}',
            error: error,
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
  Future<List<int>> rpc(String method, [List<int>? data]) => _doOnReady(
        () => _sendCommand<SpinifyRPCResult>(
          SpinifyRPCRequest(
            id: _getNextCommandId(),
            timestamp: DateTime.now(),
            method: method,
            data: data ?? const <int>[],
          ),
        ).then<List<int>>((reply) => reply.data),
      );

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
  void _onReply(SpinifyReply reply) {
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
class _PendingReply<R extends SpinifyReply> {
  _PendingReply(this.command) : _completer = Completer<R>();

  final SpinifyCommand command;
  final Completer<R> _completer;

  Future<R> get future => _completer.future;

  bool get isCompleted => _completer.isCompleted;

  void complete(R reply) => _completer.complete(reply);

  void completeError(SpinifyReplyException error, StackTrace stackTrace) =>
      _completer.completeError(error, stackTrace);
}
