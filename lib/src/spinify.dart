import 'dart:async';
import 'dart:collection';

import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:meta/meta.dart';

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
import 'model/subscription_state.dart';
import 'model/subscription_states.dart';
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
  Timer? _pingTimer;

  /// Registry of client subscriptions.
  final Map<String, _SpinifyClientSubscriptionImpl>
      _clientSubscriptionRegistry = <String, _SpinifyClientSubscriptionImpl>{};

  /// Registry of server subscriptions.
  final Map<String, _SpinifyServerSubscriptionImpl>
      _serverSubscriptionRegistry = <String, _SpinifyServerSubscriptionImpl>{};

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
  @protected
  @nonVirtual
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
  @protected
  @nonVirtual
  void _setState(SpinifyState state) {
    if (isClosed) return; // Client is closed, do not notify about states.
    final prev = _metrics.state, next = state;
    // coverage:ignore-start
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
    // coverage:ignore-end
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
  @nonVirtual
  int _getNextCommandId() {
    if (_metrics.commandId == kMaxInt) _metrics.commandId = 1;
    return _metrics.commandId++;
  }

  // --- Init --- //

  /// Initialization from constructor
  @safe
  @protected
  @nonVirtual
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
  @protected
  @nonVirtual
  void _setUpHealthCheckTimer() {
    _tearDownHealthCheckTimer();
    // coverage:ignore-start

    void warning(String message) {
      //debugger();
      _log(
        const SpinifyLogLevel.warning(),
        'health_check_error',
        message,
        <String, Object?>{},
      );
    }

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

    // coverage:ignore-end
  }

  /// Tear down health check timer.
  @safe
  @protected
  @nonVirtual
  void _tearDownHealthCheckTimer() {
    _healthTimer?.cancel();
    _healthTimer = null;
  }

  /// Set up refresh connection timer.
  @safe
  @protected
  @nonVirtual
  void _setUpRefreshConnection() {
    _tearDownRefreshConnection();
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
      // coverage:ignore-start
      final duration = ttl.difference(DateTime.now()) - config.timeout;
      if (duration < Duration.zero) {
        _log(
          const SpinifyLogLevel.warning(),
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
      // coverage:ignore-end
      _refreshTimer = Timer(duration, () async {
        if (!state.isConnected) return;
        final token = await config.getToken?.call();
        if (token == null || token.isEmpty) {
          _log(
            const SpinifyLogLevel.warning(),
            'refresh_connection_cancelled',
            'Spinify token is null or empty for refresh connection',
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
        } on Object catch (error, stackTrace) {
          _log(
            const SpinifyLogLevel.error(),
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
        } finally {
          if (state.isConnected) _setUpRefreshConnection();
        }
        _log(
          const SpinifyLogLevel.config(),
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

  /// Tear down refresh connection timer.
  @safe
  @protected
  @nonVirtual
  void _tearDownRefreshConnection() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Set up reconnect timer.
  @safe
  @protected
  @nonVirtual
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
    _log(
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
        _log(
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
  @protected
  @nonVirtual
  void _tearDownReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// Start or restart keepalive timer,
  /// you should restart it after each received ping message.
  /// Or connection will be closed by timeout.
  @safe
  @protected
  @nonVirtual
  void _setUpPingTimer() {
    _tearDownPingTimer();
    // coverage:ignore-start
    if (isClosed || !state.isConnected) return;
    // coverage:ignore-end
    if (state case SpinifyState$Connected(:Duration? pingInterval)
        when pingInterval != null && pingInterval > Duration.zero) {
      _pingTimer = Timer(
        pingInterval + config.serverPingDelay,
        () async {
          // Reconnect if no pong received.
          if (state case SpinifyState$Connected(:String url)) {
            _log(
              const SpinifyLogLevel.warning(),
              'no_pong_reconnect',
              'No pong from server - reconnecting',
              <String, Object?>{
                'url': url,
                'pingInterval': pingInterval,
                'serverPingDelay': config.serverPingDelay,
              },
            );
            try {
              _internalDisconnect(
                code: const SpinifyDisconnectCode.noPingFromServer(),
                reason: 'no ping from server',
                reconnect: true,
              );
            } finally {
              _internalReconnect(url).ignore();
            }
          }
          /* disconnect(
            SpinifyConnectingCode.noPing,
            'No ping from server',
          ); */
        },
      );
    }
  }

  /// Tear down ping timer.
  @safe
  @protected
  @nonVirtual
  void _tearDownPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
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
  @nonVirtual
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

  @unsafe
  @protected
  @nonVirtual
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
  @nonVirtual
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
  @protected
  @nonVirtual
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
  @protected
  @nonVirtual
  Future<void> _internalReconnect(String url) async {
    if (state.isConnected || state.isConnecting) {
      _internalDisconnect(
        code: const SpinifyDisconnectCode.normalClosure(),
        reason: 'normal closure',
        reconnect: false,
      );
    }
    final readyCompleter = _readyCompleter = switch (_readyCompleter) {
      Completer<void> value when !value.isCompleted => value,
      _ => Completer<void>(),
    };
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

      void checkStillConnecting() {
        // coverage:ignore-start
        if (isClosed) {
          _log(
            const SpinifyLogLevel.warning(),
            'closed_during_connect_error',
            'Client is closed during connect',
            <String, Object?>{},
          );
          throw const SpinifyConnectionException(
            message: 'Client is closed during connect',
          );
        } else if (!state.isConnecting) {
          _log(
            const SpinifyLogLevel.warning(),
            'state_changed_during_connect_error',
            'State changed during connect',
            <String, Object?>{
              'state': state,
            },
          );
          throw const SpinifyConnectionException(
            message: 'State changed during connect',
          );
        } else if (!identical(url, _metrics.reconnectUrl)) {
          _log(
            const SpinifyLogLevel.warning(),
            'url_changed_during_connect_error',
            'URL changed during connect',
            <String, Object?>{
              'url': url,
              'reconnectUrl': _metrics.reconnectUrl,
            },
          );
          throw const SpinifyConnectionException(
            message: 'URL changed during connect',
          );
        } else if (readyCompleter.isCompleted) {
          _log(
            const SpinifyLogLevel.warning(),
            'ready_completer_completed_error',
            'Ready completer is already completed',
            <String, Object?>{
              'readyCompleter': readyCompleter,
            },
          );
          throw const SpinifyConnectionException(
            message: 'Ready completer is already completed',
          );
        } else if (!identical(_readyCompleter, readyCompleter)) {
          _log(
            const SpinifyLogLevel.warning(),
            'ready_completer_changed_error',
            'Ready completer changed during connect',
            <String, Object?>{
              'readyCompleter': _readyCompleter,
              'newReadyCompleter': readyCompleter,
            },
          );
          throw const SpinifyConnectionException(
            message: 'Ready completer changed during connect',
          );
        }
        // coverage:ignore-end
      }

      checkStillConnecting();

      // Prepare connect request.
      final SpinifyConnectRequest request;
      {
        final token = await config.getToken?.call();
        final payload = await config.getPayload?.call();

        checkStillConnecting();

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

      checkStillConnecting();

      // Create a new transport
      final ws = _transport = await _webSocketConnect(
        url: url,
        headers: config.headers,
        protocols: <String>[_codec.protocol],
      );

      checkStillConnecting();

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

      checkStillConnecting();

      final result = await connectResultCompleter.future;

      checkStillConnecting();

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

      _onReply(result); // Handle connect reply
      handleReply = _onReply; // Switch to normal reply handler

      _setUpRefreshConnection(); // Start refresh connection timer
      _setUpPingTimer(); // Start expecting ping messages

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

      final transport = _transport; // Close transport
      if (transport != null && !transport.isClosed) transport.close();
      _transport = null;

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
  @nonVirtual
  Future<void> disconnect() => _interactiveDisconnect();

  /// User initiated disconnect.
  @safe
  @protected
  @nonVirtual
  Future<void> _interactiveDisconnect() async {
    try {
      _tearDownReconnectTimer();
      _tearDownPingTimer();
      _metrics.reconnectUrl = null;
      _internalDisconnect(
        code: const SpinifyDisconnectCode.normalClosure(),
        reason: 'normal closure',
        reconnect: false,
      );
    } on Object catch (error, stackTrace) {
      // coverage:ignore-start
      // Normally we should not get here.
      _log(
        const SpinifyLogLevel.warning(),
        'disconnect_error',
        'Error on disconnect',
        <String, Object?>{
          'error': error,
          'stackTrace': stackTrace,
        },
      );
      // coverage:ignore-end
    }
  }

  /// Library initiated disconnect.
  @safe
  @protected
  @nonVirtual
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
        replyMessage: 'Disconnected',
        temporary: true,
      );
      const stackTrace = StackTrace.empty;
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
        c.completeError(
          const SpinifyConnectionException(
            message: 'Disconnected during connection',
          ),
          stackTrace,
        );
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
    }
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

  // --- Close --- //

  @safe
  @override
  @nonVirtual
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
  @protected
  @nonVirtual
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
  @protected
  @nonVirtual
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
  @nonVirtual
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

  @unsafe
  @override
  @nonVirtual
  @Throws([SpinifyRPCException])
  Future<List<int>> rpc(String method, [List<int>? data]) async {
    try {
      return await _doOnReady(() => _sendCommand<SpinifyRPCResult>(
            SpinifyRPCRequest(
              id: _getNextCommandId(),
              timestamp: DateTime.now(),
              method: method,
              data: data ?? const <int>[],
            ),
          )).then<List<int>>((reply) => reply.data);
    } on SpinifyRPCException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(SpinifyRPCException(error: error), stackTrace);
    }
  }
  /*  => _doOnReady(
        () => _sendCommand<SpinifyRPCResult>(
          SpinifyRPCRequest(
            id: _getNextCommandId(),
            timestamp: DateTime.now(),
            method: method,
            data: data ?? const <int>[],
          ),
        ).then<List<int>>((reply) => reply.data),
      ); */

  // --- Subscriptions and Channels --- //

  @safe
  @override
  @nonVirtual
  SpinifySubscription? getSubscription(String channel) =>
      _clientSubscriptionRegistry[channel] ??
      _serverSubscriptionRegistry[channel];

  @safe
  @override
  @nonVirtual
  SpinifyClientSubscription? getClientSubscription(String channel) =>
      _clientSubscriptionRegistry[channel];

  @safe
  @override
  @nonVirtual
  SpinifyServerSubscription? getServerSubscription(String channel) =>
      _serverSubscriptionRegistry[channel];

  @safe
  @override
  @nonVirtual
  SpinifyClientSubscription newSubscription(
    String channel, {
    SpinifySubscriptionConfig? config,
    bool subscribe = false,
  }) {
    assert(
      channel.isNotEmpty,
      'Channel should not be empty',
    );
    assert(
      channel.trim() == channel,
      'Channel should not have leading or trailing spaces',
    );
    assert(
      channel.length <= 255,
      'Channel should not be longer than 255 characters',
    );
    assert(
      channel.codeUnits.every((code) => code >= 0 && code <= 0x7f),
      'Channel should contain only ASCII characters',
    );

    final sub = _clientSubscriptionRegistry[channel] ??
        _serverSubscriptionRegistry[channel];
    if (sub != null) {
      _log(
        const SpinifyLogLevel.warning(),
        'subscription_exists_error',
        'Subscription already exists',
        <String, Object?>{
          'channel': channel,
          'subscription': sub,
        },
      );
      throw SpinifySubscriptionException(
        channel: channel,
        message: 'Subscription already exists',
      );
    }
    final newSub =
        _clientSubscriptionRegistry[channel] = _SpinifyClientSubscriptionImpl(
      client: this,
      channel: channel,
      config: config ?? const SpinifySubscriptionConfig.byDefault(),
    );
    if (subscribe) newSub.subscribe();
    return newSub;
  }

  @override
  Future<void> removeSubscription(
      SpinifyClientSubscription subscription) async {
    final subFromRegistry =
        _clientSubscriptionRegistry.remove(subscription.channel);
    try {
      await subFromRegistry?.unsubscribe();
      // coverage:ignore-start
      assert(
        subFromRegistry != null,
        'Subscription not found in the registry',
      );
      assert(
        identical(subFromRegistry, subscription),
        'Subscription should be the same instance as in the registry',
      );
      // coverage:ignore-end
    } on Object catch (error, stackTrace) {
      _log(
        const SpinifyLogLevel.warning(),
        'subscription_remove_error',
        'Error removing subscription',
        <String, Object?>{
          'channel': subscription.channel,
          'subscription': subscription,
        },
      );
      Error.throwWithStackTrace(
        SpinifySubscriptionException(
          channel: subscription.channel,
          message: 'Error while unsubscribing',
          error: error,
        ),
        stackTrace,
      );
    } finally {
      subFromRegistry?.close();
    }
  }

  // --- Publish --- //

  @unsafe
  @override
  Future<void> publish(String channel, List<int> data) =>
      getSubscription(channel)?.publish(data) ??
      Future.error(
        SpinifySubscriptionException(
          channel: channel,
          message: 'Subscription not found',
        ),
        StackTrace.current,
      );

  // --- Presence --- //

  @unsafe
  @override
  @nonVirtual
  @Throws([SpinifyConnectionException, SpinifySubscriptionException])
  Future<Map<String, SpinifyClientInfo>> presence(String channel) =>
      getSubscription(channel)?.presence() ??
      Future.error(
        SpinifySubscriptionException(
          channel: channel,
          message: 'Subscription not found',
        ),
        StackTrace.current,
      );

  @unsafe
  @override
  @nonVirtual
  @Throws([SpinifyConnectionException, SpinifySubscriptionException])
  Future<SpinifyPresenceStats> presenceStats(String channel) =>
      getSubscription(channel)?.presenceStats() ??
      Future.error(
        SpinifySubscriptionException(
          channel: channel,
          message: 'Subscription not found',
        ),
        StackTrace.current,
      );

  // --- History --- //

  @unsafe
  @override
  @nonVirtual
  @Throws([SpinifyConnectionException, SpinifySubscriptionException])
  Future<SpinifyHistory> history(
    String channel, {
    int? limit,
    SpinifyStreamPosition? since,
    bool? reverse,
  }) =>
      getSubscription(channel)?.history(
        limit: limit,
        since: since,
        reverse: reverse,
      ) ??
      Future.error(
        SpinifySubscriptionException(
          channel: channel,
          message: 'Subscription not found',
        ),
        StackTrace.current,
      );

  // --- Replies --- //

  @safe
  @sideEffect
  @nonVirtual
  void _onEvent(SpinifyChannelEvent event) {
    _eventController.add(event); // Add event to the broadcast stream.
    _log(
      const SpinifyLogLevel.debug(),
      'push_received',
      'Push ${event.type} received',
      <String, Object?>{
        'event': event,
      },
    );
    switch (event) {
      case SpinifyChannelEvent(channel: ''):
        /* ignore push without channel */
        break;
      case SpinifyDisconnect disconnect:
        _internalDisconnect(
          code: disconnect.code,
          reason: disconnect.reason,
          reconnect: disconnect.reconnect,
        );
      case SpinifySubscribe _:
        // Add server subscription to the registry on subscribe event.
        _serverSubscriptionRegistry.putIfAbsent(
            event.channel,
            () => _SpinifyServerSubscriptionImpl(
                  client: this,
                  channel: event.channel,
                  recoverable: event.recoverable,
                  epoch: event.since.epoch,
                  offset: event.since.offset,
                ))
          ..onEvent(event)
          .._setState(SpinifySubscriptionState.subscribed(data: event.data));
      case SpinifyUnsubscribe _:
        // Remove server subscription from the registry.
        _serverSubscriptionRegistry.remove(event.channel)
          ?..onEvent(event)
          .._setState(SpinifySubscriptionState.unsubscribed());
        // Unsubscribe client subscription on unsubscribe event.
        if (_clientSubscriptionRegistry[event.channel]
            case _SpinifyClientSubscriptionImpl subscription) {
          subscription.onEvent(event);
          if (event.code < 2500) {
            // Unsubscribe client subscription on unsubscribe event.
            subscription
                ._unsubscribe(
                  code: event.code,
                  reason: event.reason,
                  sendUnsubscribe: false,
                )
                .ignore();
          } else {
            // Resubscribe client subscription on unsubscribe event.
            subscription._resubscribe().ignore();
          }
        }
      default:
        // Notify subscription about new event.
        final sub = _serverSubscriptionRegistry[event.channel] ??
            _clientSubscriptionRegistry[event.channel];
        if (sub != null) {
          sub.onEvent(event);
          if (event is SpinifyPublication && sub.recoverable) {
            // Update subscription offset on publication.
            if (event.offset case fixnum.Int64 newOffset when newOffset > 0)
              sub.offset = newOffset;
          }
        } else {
          _log(
            const SpinifyLogLevel.warning(),
            'subscription_not_found_error',
            'Subscription ${event.channel} not found for event',
            <String, Object?>{
              'channel': event.channel,
              'event': event,
            },
          );
        }
    }
  }

  /// Called when [SpinifyReply] received from the server.
  @safe
  @sideEffect
  @nonVirtual
  void _onReply(SpinifyReply reply) {
    try {
      // coverage:ignore-start
      if (reply.id < 0 || reply.id > _metrics.commandId) {
        _log(
          const SpinifyLogLevel.warning(),
          'reply_id_error',
          'Reply ID out of range',
          <String, Object?>{
            'reply': reply,
          },
        );
        return;
      }
      // coverage:ignore-end

      // If reply is a result then find pending reply and complete it.
      if (reply.isResult) {
        if (reply.id case int id when id > 0) {
          final completer = _replies.remove(id);
          if (completer == null) {
            // Thats okay, we can send some commands asynchronously
            // and do not wait for reply.
            // E.g. connection command or ping command.
          } else if (completer.isCompleted) {
            _log(
              const SpinifyLogLevel.warning(),
              'reply_completer_error',
              'Reply completer already completed',
              <String, Object?>{
                'reply': reply,
              },
            );
            return;
          } else if (reply is SpinifyErrorResult) {
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
      }

      // Handle different types of replies.
      switch (reply) {
        case SpinifyPush push:
          _onEvent(push.event);
        case SpinifyServerPing _:
          final command = SpinifyPingRequest(timestamp: DateTime.now());
          _metrics
            ..lastPingAt = command.timestamp
            ..receivedPings = _metrics.receivedPings + 1;
          if (state case SpinifyState$Connected(:bool sendPong) when sendPong) {
            // No need to handle error in a special way -
            // if pong can't be sent but connection is closed anyway.
            _sendCommandAsync(command).ignore();
          }
          _log(
            const SpinifyLogLevel.debug(),
            'server_ping_received',
            'Ping from server received, pong sent',
            <String, Object?>{
              'ping': reply,
              'pong': command,
            },
          );
          _setUpPingTimer();
        case SpinifyConnectResult _:
          // Update server subscriptions.
          final newServerSubs =
              reply.subs ?? <String, SpinifySubscribeResult>{};
          for (final entry in newServerSubs.entries) {
            final MapEntry<String, SpinifySubscribeResult>(
              key: channel,
              value: value
            ) = entry;
            final sub = _serverSubscriptionRegistry.putIfAbsent(
                channel,
                () => _SpinifyServerSubscriptionImpl(
                      client: this,
                      channel: channel,
                      recoverable: value.recoverable,
                      epoch: value.since.epoch,
                      offset: value.since.offset,
                    ))
              .._setState(
                  SpinifySubscriptionState.subscribed(data: value.data));

            // Notify about new publications.
            for (var publication in value.publications) {
              // If publication has wrong channel, fix it.
              // Thats a workaround because we do not have channel
              // in the publication in this server SpinifyConnectResult reply.
              if (publication.channel != channel) {
                // coverage:ignore-start
                assert(
                  publication.channel.isEmpty,
                  'Publication contains wrong channel',
                );
                // coverage:ignore-end
                publication = publication.copyWith(channel: channel);
              }
              _eventController.add(publication);
              sub.onEvent(publication);
              // Update subscription offset on publication.
              if (sub.recoverable) {
                if (publication.offset case fixnum.Int64 newOffset
                    when newOffset > sub.offset) {
                  sub.offset = newOffset;
                }
              }
            }
          }

          // Remove server subscriptions that are not in the new list.
          final currentServerSubs = _serverSubscriptionRegistry.keys.toSet();
          for (final key in currentServerSubs) {
            if (newServerSubs.containsKey(key)) continue;
            _serverSubscriptionRegistry.remove(key)
              ?.._setState(SpinifySubscriptionState.unsubscribed())
              ..close();
          }

          // We should resubscribe client subscriptions here.
          for (final subscription in _clientSubscriptionRegistry.values)
            subscription._resubscribe().ignore();
        case SpinifyErrorResult _:
          break;
        case SpinifySubscribeResult _:
          break;
        case SpinifyUnsubscribeResult _:
          break;
        case SpinifyPublishResult _:
          break;
        case SpinifyPresenceResult _:
          break;
        case SpinifyPresenceStatsResult _:
          break;
        case SpinifyHistoryResult _:
          break;
        case SpinifyPingResult _:
          break;
        case SpinifyRPCResult _:
          break;
        case SpinifyRefreshResult _:
          break;
        case SpinifySubRefreshResult _:
          break;
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

abstract base class _SpinifySubscriptionBase implements SpinifySubscription {
  _SpinifySubscriptionBase({
    required Spinify client,
    required this.channel,
    required this.recoverable,
    required this.epoch,
    required this.offset,
  }) : _client = client {
    _metrics = _client._metrics.channels
        .putIfAbsent(channel, SpinifyMetrics$Channel$Mutable.new);
  }

  @override
  final String channel;

  /// Spinify client
  final Spinify _client;

  /// Spinify channel metrics.
  late final SpinifyMetrics$Channel$Mutable _metrics;

  final StreamController<SpinifySubscriptionState> _stateController =
      StreamController<SpinifySubscriptionState>.broadcast(sync: true);

  final StreamController<SpinifyChannelEvent> _eventController =
      StreamController<SpinifyChannelEvent>.broadcast(sync: true);

  Future<T> _sendCommand<T extends SpinifyReply>(
    SpinifyCommand Function(int nextId) builder,
  ) =>
      _client._doOnReady(
        () => _client._sendCommand<T>(
          builder(_client._getNextCommandId()),
        ),
      );

  @override
  bool recoverable;

  @override
  String epoch;

  @override
  fixnum.Int64 offset;

  @override
  SpinifySubscriptionState get state => _metrics.state;

  @override
  SpinifySubscriptionStates get states =>
      SpinifySubscriptionStates(_stateController.stream);

  @override
  SpinifyChannelEvents<SpinifyChannelEvent> get stream =>
      SpinifyChannelEvents(_eventController.stream);

  /// Receives notification about new event from the client.
  /// Available only for internal use.
  @internal
  @sideEffect
  @mustCallSuper
  void onEvent(SpinifyChannelEvent event) {
    // coverage:ignore-start
    assert(
      event.channel == channel,
      'Subscription "$channel" received event for another channel',
    );
    // coverage:ignore-end
    _eventController.add(event);
    _client._log(
      const SpinifyLogLevel.debug(),
      'subscription_event_received',
      'Subscription "$channel" received ${event.type} event',
      <String, Object?>{
        'channel': channel,
        'subscription': this,
        'event': event,
        if (event is SpinifyPublication) 'publication': event,
      },
    );
  }

  @mustCallSuper
  void _setState(SpinifySubscriptionState state) {
    final previous = _metrics.state;
    if (previous == state) return;
    _stateController.add(_metrics.state = state);
    _client._log(
      const SpinifyLogLevel.config(),
      'subscription_state_changed',
      'Subscription "$channel" state changed to ${state.type}',
      <String, Object?>{
        'channel': channel,
        'subscription': this,
        'previous': previous,
        'state': state,
      },
    );
  }

  @interactive
  @mustCallSuper
  void close() {
    _stateController.close().ignore();
    _eventController.close().ignore();
    // coverage:ignore-start
    assert(state.isUnsubscribed,
        'Subscription "$channel" is not unsubscribed before closing');
    // coverage:ignore-end
  }

  @unsafe
  @override
  @interactive
  Future<void> ready() async {
    if (_client.isClosed)
      throw SpinifySubscriptionException(
        channel: channel,
        message: 'Client is closed',
      );
    if (_metrics.state.isSubscribed) return;
    if (_stateController.isClosed)
      throw SpinifySubscriptionException(
        channel: channel,
        message: 'Subscription is closed permanently',
      );
    final state = await _stateController.stream
        .firstWhere((state) => !state.isSubscribing);
    if (!state.isSubscribed)
      throw SpinifySubscriptionException(
        channel: channel,
        message: 'Subscription failed to subscribe',
      );
  }

  @override
  @interactive
  Future<SpinifyHistory> history({
    int? limit,
    SpinifyStreamPosition? since,
    bool? reverse,
  }) =>
      _sendCommand<SpinifyHistoryResult>(
        (id) => SpinifyHistoryRequest(
          id: id,
          channel: channel,
          timestamp: DateTime.now(),
          limit: limit,
          since: since,
          reverse: reverse,
        ),
      ).then<SpinifyHistory>(
        (reply) => SpinifyHistory(
          publications: List<SpinifyPublication>.unmodifiable(
              reply.publications.map((pub) => pub.copyWith(channel: channel))),
          since: reply.since,
        ),
      );

  @override
  @interactive
  Future<Map<String, SpinifyClientInfo>> presence() =>
      _sendCommand<SpinifyPresenceResult>(
        (id) => SpinifyPresenceRequest(
          id: id,
          channel: channel,
          timestamp: DateTime.now(),
        ),
      ).then<Map<String, SpinifyClientInfo>>((reply) => reply.presence);

  @override
  @interactive
  Future<SpinifyPresenceStats> presenceStats() =>
      _sendCommand<SpinifyPresenceStatsResult>(
        (id) => SpinifyPresenceStatsRequest(
          id: id,
          channel: channel,
          timestamp: DateTime.now(),
        ),
      ).then<SpinifyPresenceStats>(
        (reply) => SpinifyPresenceStats(
          channel: channel,
          clients: reply.numClients,
          users: reply.numUsers,
        ),
      );

  @override
  @interactive
  Future<void> publish(List<int> data) => _sendCommand<SpinifyPublishResult>(
        (id) => SpinifyPublishRequest(
          id: id,
          channel: channel,
          timestamp: DateTime.now(),
          data: data,
        ),
      );
}

final class _SpinifyServerSubscriptionImpl extends _SpinifySubscriptionBase
    implements SpinifyServerSubscription {
  _SpinifyServerSubscriptionImpl({
    required super.client,
    required super.channel,
    required super.recoverable,
    required super.epoch,
    required super.offset,
  });

  @override
  SpinifyChannelEvents<SpinifyChannelEvent> get stream =>
      _client.stream.filter(channel: channel);
}

final class _SpinifyClientSubscriptionImpl extends _SpinifySubscriptionBase
    implements SpinifyClientSubscription {
  _SpinifyClientSubscriptionImpl({
    required super.client,
    required super.channel,
    required this.config,
  }) : super(
          recoverable: config.recoverable,
          epoch: config.since?.epoch ?? '',
          offset: config.since?.offset ?? fixnum.Int64.ZERO,
        );

  @override
  final SpinifySubscriptionConfig config;

  /// Whether the subscription should recover.
  bool _recover = false;

  /// Interactively subscribes to the channel.
  @override
  @interactive
  Future<void> subscribe() async {
    // Check if the client is connected
    switch (_client.state) {
      case SpinifyState$Connected _:
        break;
      case SpinifyState$Connecting _:
      case SpinifyState$Disconnected _:
        await _client.ready();
      case SpinifyState$Closed _:
        throw SpinifySubscriptionException(
          channel: channel,
          message: 'Client is closed',
        );
    }

    // Check if the subscription is already subscribed
    switch (state) {
      case SpinifySubscriptionState$Subscribed _:
        return;
      case SpinifySubscriptionState$Subscribing _:
        await ready();
      case SpinifySubscriptionState$Unsubscribed _:
        await _resubscribe();
    }
  }

  /// Interactively unsubscribes from the channel.
  @override
  @interactive
  Future<void> unsubscribe([
    int code = 0,
    String reason = 'unsubscribe called',
  ]) =>
      _unsubscribe(
        code: code,
        reason: reason,
        sendUnsubscribe: true,
      );

  /// Unsubscribes from the channel.
  Future<void> _unsubscribe({
    required int code,
    required String reason,
    required bool sendUnsubscribe,
  }) async {
    final currentState = _metrics.state;
    _tearDownResubscribeTimer();
    _tearDownRefreshSubscriptionTimer();
    if (currentState.isUnsubscribed) return;
    _setState(SpinifySubscriptionState$Unsubscribed());
    _metrics.lastUnsubscribeAt = DateTime.now();
    _metrics.unsubscribes++;
    try {
      if (sendUnsubscribe &&
          currentState.isSubscribed &&
          _client.state.isConnected) {
        await _sendCommand<SpinifyUnsubscribeResult>(
          (id) => SpinifyUnsubscribeRequest(
            id: id,
            channel: channel,
            timestamp: DateTime.now(),
          ),
        );
      }
    } on Object catch (error, stackTrace) {
      _client._log(
        const SpinifyLogLevel.error(),
        'subscription_unsubscribe_error',
        'Subscription "$channel" failed to unsubscribe',
        <String, Object?>{
          'channel': channel,
          'subscription': this,
          'error': error,
          'stackTrace': stackTrace,
        },
      );
      _client._transport?.close(4, 'unsubscribe error');
      if (error is SpinifyException) rethrow;
      Error.throwWithStackTrace(
        SpinifySubscriptionException(
          channel: channel,
          message: 'Error while unsubscribing',
          error: error,
        ),
        stackTrace,
      );
    }
  }

  /// `SubscriptionImpl{}._resubscribe()` from `centrifuge` package
  Future<void> _resubscribe() async {
    if (!_metrics.state.isUnsubscribed) return;
    try {
      _setState(SpinifySubscriptionState$Subscribing());

      final token = await config.getToken?.call();
      // Token can be null if it is not required for subscription.
      if (token != null && token.length <= 5) {
        throw SpinifySubscriptionException(
          channel: channel,
          message: 'Subscription token is empty',
        );
      }

      final data = await config.getPayload?.call();

      final recover =
          _recover && offset > fixnum.Int64.ZERO && epoch.isNotEmpty;

      final result = await _sendCommand<SpinifySubscribeResult>(
        (id) => SpinifySubscribeRequest(
          id: id,
          channel: channel,
          timestamp: DateTime.now(),
          token: token,
          recoverable: recoverable,
          recover: recover,
          offset: recover ? offset : null,
          epoch: recover ? epoch : null,
          positioned: config.positioned,
          joinLeave: config.joinLeave,
          data: data,
        ),
      );

      if (state.isUnsubscribed) {
        _client._log(
          const SpinifyLogLevel.debug(),
          'subscription_resubscribe_skipped',
          'Subscription "$channel" resubscribe skipped, '
              'subscription is unsubscribed.',
          <String, Object?>{
            'channel': channel,
            'subscription': this,
          },
        );
        await _unsubscribe(
          code: 0,
          reason: 'resubscribe skipped',
          sendUnsubscribe: false,
        );
      }

      // If subscription is recoverable and server sends recoverable flag
      // then we should update epoch and offset values.
      if (result.recoverable) {
        _recover = true;
        epoch = result.since.epoch;
        offset = result.since.offset;
      }

      _setState(SpinifySubscriptionState$Subscribed(data: result.data));

      // Set up refresh subscription timer if needed.
      if (result.expires) {
        if (result.ttl case DateTime ttl when ttl.isAfter(DateTime.now())) {
          _setUpRefreshSubscriptionTimer(ttl: ttl);
        } else {
          // coverage:ignore-start
          assert(
            false,
            'Subscription "$channel" has invalid TTL: ${result.ttl}',
          );
          // coverage:ignore-end
        }
      }

      // Handle received publications and update offset.
      for (final pub in result.publications) {
        _client._eventController.add(pub);
        onEvent(pub);
        if (pub.offset case fixnum.Int64 value when value > offset) {
          offset = value;
        }
      }

      _onSubscribed(); // Successful subscription completed

      _client._log(
        const SpinifyLogLevel.config(),
        'subscription_subscribed',
        'Subscription "$channel" subscribed',
        <String, Object?>{
          'channel': channel,
          'subscription': this,
        },
      );
    } on Object catch (error, stackTrace) {
      _client._log(
        const SpinifyLogLevel.error(),
        'subscription_resubscribe_error',
        'Subscription "$channel" failed to resubscribe',
        <String, Object?>{
          'channel': channel,
          'subscription': this,
          'error': error,
          'stackTrace': stackTrace,
        },
      );
      switch (error) {
        case SpinifyErrorResult result:
          if (result.code == 109) {
            _setUpResubscribeTimer(); // Token expired error, retry resubscribe
          } else if (result.temporary) {
            _setUpResubscribeTimer(); // Temporary error, retry resubscribe
          } else {
            // Disable resubscribe timer and unsubscribe
            _unsubscribe(
              code: result.code,
              reason: result.message,
              sendUnsubscribe: false,
            ).ignore();
          }
        case SpinifySubscriptionException _:
          _setUpResubscribeTimer(); // Some spinify exception, retry resubscribe
          rethrow;
        default:
          _setUpResubscribeTimer(); // Unknown error, retry resubscribe
      }
      Error.throwWithStackTrace(
        SpinifySubscriptionException(
          channel: channel,
          message: 'Failed to resubscribe to "$channel"',
          error: error,
        ),
        stackTrace,
      );
    }
  }

  /// Successful subscription completed.
  void _onSubscribed() {
    _tearDownResubscribeTimer();
    _metrics.lastSubscribeAt = DateTime.now();
    _metrics.subscribes++;
  }

  /// Resubscribe timer.
  Timer? _resubscribeTimer;

  /// Set up resubscribe timer.
  void _setUpResubscribeTimer() {
    _resubscribeTimer?.cancel();
    final attempt = _metrics.resubscribeAttempts ?? 0;
    final delay = Backoff.nextDelay(
      attempt,
      _client.config.connectionRetryInterval.min.inMilliseconds,
      _client.config.connectionRetryInterval.max.inMilliseconds,
    );
    _metrics.resubscribeAttempts = attempt + 1;
    if (delay <= Duration.zero) {
      if (!state.isUnsubscribed) return;
      _client._log(
        const SpinifyLogLevel.config(),
        'subscription_resubscribe_attempt',
        'Resubscibing to $channel immediately.',
        {
          'channel': channel,
          'delay': delay,
          'subscription': this,
          'attempts': attempt,
        },
      );
      Future<void>.sync(subscribe).ignore();
      return;
    }
    _client._log(
      const SpinifyLogLevel.debug(),
      'subscription_resubscribe_delayed',
      'Setting up resubscribe timer for $channel '
          'after ${delay.inMilliseconds} ms.',
      {
        'channel': channel,
        'delay': delay,
        'subscription': this,
        'attempts': attempt,
      },
    );
    _metrics.nextResubscribeAt = DateTime.now().add(delay);
    _resubscribeTimer = Timer(delay, () {
      if (!state.isUnsubscribed) return;
      _client._log(
        const SpinifyLogLevel.debug(),
        'subscription_resubscribe_attempt',
        'Resubscribing to $channel after ${delay.inMilliseconds} ms.',
        {
          'channel': channel,
          'subscription': this,
          'attempts': attempt,
        },
      );
      Future<void>.sync(_resubscribe).ignore();
    });
  }

  /// Tear down resubscribe timer.
  void _tearDownResubscribeTimer() {
    _metrics
      ..resubscribeAttempts = 0
      ..nextResubscribeAt = null;
    _resubscribeTimer?.cancel();
    _resubscribeTimer = null;
  }

  /// Refresh subscription timer.
  Timer? _refreshTimer;

  /// Set up refresh subscription timer.
  void _setUpRefreshSubscriptionTimer({required DateTime ttl}) {
    _tearDownRefreshSubscriptionTimer();
    _metrics.ttl = ttl;
    _refreshTimer = Timer(ttl.difference(DateTime.now()), _refreshToken);
  }

  /// Tear down refresh subscription timer.
  void _tearDownRefreshSubscriptionTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _metrics.ttl = null;
  }

  /// Refresh subscription token.
  void _refreshToken() => runZonedGuarded<void>(
        () async {
          _tearDownRefreshSubscriptionTimer();
          if (!state.isSubscribed || !_client.state.isConnected) return;
          final token = await config.getToken?.call();
          if (token == null || token.isEmpty) {
            throw SpinifySubscriptionException(
              channel: channel,
              message: 'Token is empty',
            );
          }
          final result = await _sendCommand<SpinifyRefreshResult>(
            (id) => SpinifySubRefreshRequest(
              id: id,
              channel: channel,
              timestamp: DateTime.now(),
              token: token,
            ),
          );

          DateTime? newTtl;
          if (result.expires) {
            if (result.ttl case DateTime ttl when ttl.isAfter(DateTime.now())) {
              newTtl = ttl;
              _setUpRefreshSubscriptionTimer(ttl: ttl);
            } else {
              // coverage:ignore-start
              assert(
                false,
                'Subscription "$channel" has invalid TTL: ${result.ttl}',
              );
              // coverage:ignore-end
            }
          }

          _client._log(
            const SpinifyLogLevel.debug(),
            'subscription_refresh_token',
            'Subscription "$channel" token refreshed',
            <String, Object?>{
              'channel': channel,
              'subscription': this,
              if (newTtl != null) 'ttl': newTtl,
            },
          );
        },
        (error, stackTrace) {
          _client._log(
            const SpinifyLogLevel.error(),
            'subscription_refresh_token_error',
            'Subscription "$channel" failed to refresh token',
            <String, Object?>{
              'channel': channel,
              'subscription': this,
              'error': error,
              'stackTrace': stackTrace,
            },
          );

          // Calculate new TTL for refresh subscription timer
          late final ttl =
              DateTime.now().add(Backoff.nextDelay(0, 5 * 1000, 10 * 1000));
          switch (error) {
            case SpinifyErrorResult result:
              if (result.temporary) {
                _setUpRefreshSubscriptionTimer(ttl: ttl);
              } else {
                // Disable refresh subscription timer and unsubscribe
                _unsubscribe(
                  code: result.code,
                  reason: result.message,
                  sendUnsubscribe: true,
                ).ignore();
              }
            case SpinifySubscriptionException _:
              _setUpRefreshSubscriptionTimer(ttl: ttl);
            default:
              _setUpRefreshSubscriptionTimer(ttl: ttl);
          }
        },
      );
}
