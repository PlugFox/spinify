import 'dart:async';
import 'dart:collection';

import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:meta/meta.dart';

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
import 'model/subscription_state.dart';
import 'model/transport_interface.dart';
import 'spinify_interface.dart';
import 'subscription_impl.dart';
import 'subscription_interface.dart';
import 'transport_ws_pb_stub.dart'
    // ignore: uri_does_not_exist
    if (dart.library.js_util) 'transport_ws_pb_js.dart'
    // ignore: uri_does_not_exist
    if (dart.library.io) 'transport_ws_pb_vm.dart';
import 'util/backoff.dart';

/// Base class for Spinify client.
abstract base class SpinifyBase implements ISpinify {
  /// Create a new Spinify client.
  SpinifyBase({required this.config}) {
    _init();
  }

  /// Counter for command messages.
  int _getNextCommandId() {
    if (_metrics.commandId == kMaxInt) _metrics.commandId = 1;
    return _metrics.commandId++;
  }

  @override
  bool get isClosed => state.isClosed;

  /// Spinify config.
  @override
  @nonVirtual
  final SpinifyConfig config;

  late final SpinifyTransportBuilder _createTransport;
  ISpinifyTransport? _transport;

  final SpinifyMetrics$Mutable _metrics = SpinifyMetrics$Mutable();

  /// Client initialization (from constructor).
  @mustCallSuper
  void _init() {
    _createTransport = config.transportBuilder ?? $create$WS$PB$Transport;
    config.logger?.call(
      const SpinifyLogLevel.info(),
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
      const SpinifyLogLevel.debug(),
      'reply',
      'Reply ${reply.type}{id: ${reply.id}} received',
      <String, Object?>{
        'reply': reply,
      },
    );
  }

  /// On disconnect from the server.
  @mustCallSuper
  Future<void> _onDisconnected() async {}

  Future<T> _doOnReady<T>(Future<T> Function() action) {
    if (state.isConnected) return action();
    return ready().then<T>((_) => action());
  }

  @override
  Future<void> close() async {
    config.logger?.call(
      const SpinifyLogLevel.info(),
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
  SpinifyState get state => _metrics.state;

  @override
  late final SpinifyStatesStream states =
      SpinifyStatesStream(_statesController.stream);

  @nonVirtual
  final StreamController<SpinifyState> _statesController =
      StreamController<SpinifyState>.broadcast();

  @nonVirtual
  void _setState(SpinifyState state) {
    final previous = _metrics.state;
    _statesController.add(_metrics.state = state);
    config.logger?.call(
      const SpinifyLogLevel.config(),
      'state_changed',
      'State changed from $previous to $state',
      <String, Object?>{
        'previous': previous,
        'state': state,
      },
    );
  }

  @override
  Future<void> _onDisconnected() async {
    await super._onDisconnected();
    if (!state.isDisconnected) {
      _setState(SpinifyState$Disconnected());
      config.logger?.call(
        const SpinifyLogLevel.config(),
        'disconnected',
        'Disconnected from server',
        <String, Object?>{},
      );
    }
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
  Future<void> send(List<int> data) => _doOnReady(
        () => _sendCommandAsync(
          SpinifySendRequest(
            timestamp: DateTime.now(),
            data: data,
          ),
        ),
      );

  Future<T> _sendCommand<T extends SpinifyReply>(SpinifyCommand command) async {
    config.logger?.call(
      const SpinifyLogLevel.debug(),
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
      final tuple = _replies.remove(command.id);
      if (tuple != null && !tuple.completer.isCompleted) {
        tuple.completer.completeError(error, stackTrace);
        config.logger?.call(
          const SpinifyLogLevel.warning(),
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
      const SpinifyLogLevel.debug(),
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
        const SpinifyLogLevel.config(),
        'send_command_async_success',
        'Command sent ${command.type}{id: ${command.id}} async successfully',
        <String, Object?>{
          'command': command,
        },
      );
    } on Object catch (error, stackTrace) {
      config.logger?.call(
        const SpinifyLogLevel.warning(),
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
  @sideEffect
  Future<void> _onReply(SpinifyReply reply) async {
    assert(
        reply.id >= 0 && reply.id <= _metrics.commandId,
        'Reply ID should be greater or equal to 0 '
        'and less or equal than command ID');
    if (reply.isResult) {
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
        if (reply is SpinifyErrorResult) {
          completer?.completeError(SpinifyReplyException(
            replyCode: reply.code,
            replyMessage: reply.message,
            temporary: reply.temporary,
          ));
        } else {
          completer?.complete(reply);
        }
      }
    }
    await super._onReply(reply);
  }

  @override
  Future<void> _onDisconnected() async {
    late final error = StateError('Client is disconnected');
    late final stackTrace = StackTrace.current;
    for (final tuple in _replies.values) {
      if (tuple.completer.isCompleted) continue;
      tuple.completer.completeError(error);
      config.logger?.call(
        const SpinifyLogLevel.warning(),
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

/// Base mixin for Spinify subscription management.
base mixin SpinifySubscriptionMixin on SpinifyBase, SpinifyCommandMixin {
  final StreamController<SpinifyChannelEvent> _eventController =
      StreamController<SpinifyChannelEvent>.broadcast();

  @override
  late final SpinifyChannelEvents<SpinifyChannelEvent> stream =
      SpinifyChannelEvents<SpinifyChannelEvent>(_eventController.stream);

  @override
  ({
    Map<String, SpinifyClientSubscription> client,
    Map<String, SpinifyServerSubscription> server
  }) get subscriptions => (
        client: UnmodifiableMapView<String, SpinifyClientSubscription>(
            _clientSubscriptionRegistry),
        server: UnmodifiableMapView<String, SpinifyServerSubscription>(
            _serverSubscriptionRegistry),
      );

  /// Registry of client subscriptions.
  final Map<String, SpinifyClientSubscriptionImpl> _clientSubscriptionRegistry =
      <String, SpinifyClientSubscriptionImpl>{};

  /// Registry of server subscriptions.
  final Map<String, SpinifyServerSubscriptionImpl> _serverSubscriptionRegistry =
      <String, SpinifyServerSubscriptionImpl>{};

  @override
  SpinifySubscription? getSubscription(String channel) =>
      _clientSubscriptionRegistry[channel] ??
      _serverSubscriptionRegistry[channel];

  @override
  SpinifyClientSubscription? getClientSubscription(String channel) =>
      _clientSubscriptionRegistry[channel];

  @override
  SpinifyServerSubscription? getServerSubscription(String channel) =>
      _serverSubscriptionRegistry[channel];

  @override
  SpinifyClientSubscription newSubscription(
    String channel, {
    SpinifySubscriptionConfig? config,
    bool subscribe = false,
  }) {
    final sub = _clientSubscriptionRegistry[channel] ??
        _serverSubscriptionRegistry[channel];
    if (sub != null) {
      this.config.logger?.call(
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
        _clientSubscriptionRegistry[channel] = SpinifyClientSubscriptionImpl(
      client: SpinifySubClient(this),
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
      assert(
        subFromRegistry != null,
        'Subscription not found in the registry',
      );
      assert(
        identical(subFromRegistry, subscription),
        'Subscription should be the same instance as in the registry',
      );
    } on Object catch (error, stackTrace) {
      config.logger?.call(
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

  @override
  Future<void> _onReply(SpinifyReply reply) async {
    await super._onReply(reply);
    if (reply is SpinifyPush) {
      // Add push to the stream.
      final event = reply.event;
      _eventController.add(event); // Add event to the broadcast stream.
      config.logger?.call(
        const SpinifyLogLevel.debug(),
        'push_received',
        'Push ${event.type} received',
        <String, Object?>{
          'event': event,
        },
      );
      if (event.channel.isEmpty) {
        /* ignore push without channel */
      } else if (event is SpinifySubscribe) {
        // Add server subscription to the registry on subscribe event.
        _serverSubscriptionRegistry.putIfAbsent(
            event.channel,
            () => SpinifyServerSubscriptionImpl(
                  client: SpinifySubClient(this),
                  channel: event.channel,
                  recoverable: event.recoverable,
                  epoch: event.since.epoch,
                  offset: event.since.offset,
                ))
          ..onEvent(event)
          ..setState(SpinifySubscriptionState.subscribed(data: event.data));
      } else if (event is SpinifyUnsubscribe) {
        // Remove server subscription from the registry on unsubscribe event.
        _serverSubscriptionRegistry.remove(event.channel)
          ?..onEvent(event)
          ..setState(SpinifySubscriptionState.unsubscribed());
        // Unsubscribe client subscription on unsubscribe event.
        _clientSubscriptionRegistry[event.channel]
          ?..onEvent(event)
          ..setState(SpinifySubscriptionState.unsubscribed());
        // TODO(plugfox): Resubscribe client subscriptions on unsubscribe
        // if unsubscribe.code >= 2500
      } else {
        // Notify subscription about new event.
        final sub = _serverSubscriptionRegistry[event.channel] ??
            _clientSubscriptionRegistry[event.channel];
        sub?.onEvent(event);
        if (sub == null) {
          assert(
            false,
            'Subscription not found for event ${event.channel}',
          );
          config.logger?.call(
            const SpinifyLogLevel.warning(),
            'subscription_not_found_error',
            'Subscription ${event.channel} not found for event',
            <String, Object?>{
              'channel': event.channel,
              'event': event,
            },
          );
        } else if (event is SpinifyPublication && sub.recoverable) {
          // Update subscription offset on publication.
          if (event.offset case fixnum.Int64 newOffset when newOffset > 0)
            sub.offset = newOffset;
        }
      }
    } else if (reply is SpinifyConnectResult) {
      // Update server subscriptions.
      final newServerSubs = reply.subs ?? <String, SpinifySubscribeResult>{};
      for (final entry in newServerSubs.entries) {
        final MapEntry<String, SpinifySubscribeResult>(
          key: channel,
          value: value
        ) = entry;
        final sub = _serverSubscriptionRegistry.putIfAbsent(
            channel,
            () => SpinifyServerSubscriptionImpl(
                  client: SpinifySubClient(this),
                  channel: channel,
                  recoverable: value.recoverable,
                  epoch: value.since.epoch,
                  offset: value.since.offset,
                ))
          ..setState(SpinifySubscriptionState.subscribed(data: value.data));
        // Notify about new publications.
        for (var publication in value.publications) {
          // If publication has wrong channel, fix it.
          // Thats a workaround because we do not have channel
          // in the publication in this server SpinifyConnectResult reply.
          if (publication.channel != channel) {
            assert(
              publication.channel.isEmpty,
              'Publication contains wrong channel',
            );
            publication = publication.copyWith(channel: channel);
          }
          _eventController.add(publication);
          sub.onEvent(publication);
          // Update subscription offset on publication.
          if (sub.recoverable) if (publication.offset
              case fixnum.Int64 newOffset when newOffset > 0)
            sub.offset = newOffset;
        }
      }
      final currentServerSubs = _serverSubscriptionRegistry.keys.toSet();
      for (final key in currentServerSubs) {
        if (newServerSubs.containsKey(key)) continue;
        _serverSubscriptionRegistry.remove(key)
          ?..setState(SpinifySubscriptionState.unsubscribed())
          ..close();
      }

      // Thats a `SpinifyConnectResult` reply.
      // We should resubscribe client subscriptions here.

      // TODO(plugfox): Resubscribe client subscriptions on connect
    }
  }

  @override
  Future<void> close() async {
    await super.close();
    final unsubscribed = SpinifySubscriptionState.unsubscribed();
    for (final sub in _clientSubscriptionRegistry.values)
      sub
        ..setState(unsubscribed)
        ..close();
    for (final sub in _serverSubscriptionRegistry.values)
      sub
        ..setState(unsubscribed)
        ..close();
    _clientSubscriptionRegistry.clear();
    _serverSubscriptionRegistry.clear();
    _eventController.close().ignore();
  }
}

/// Base mixin for Spinify client connection management (connect & disconnect).
base mixin SpinifyConnectionMixin
    on
        SpinifyBase,
        SpinifyCommandMixin,
        SpinifyStateMixin,
        SpinifySubscriptionMixin {
  Timer? _reconnectTimer;
  Completer<void>? _readyCompleter;

  @protected
  @nonVirtual
  Timer? _refreshTimer;

  @override
  Future<void> connect(String url) async {
    if (state.url == url) return;
    final completer = _readyCompleter ??= Completer<void>();
    try {
      if (state.isConnected || state.isConnecting) await disconnect();
    } on Object {/* ignore */}
    try {
      _setState(SpinifyState$Connecting(url: _metrics.reconnectUrl = url));

      // Create new transport.
      _transport = await _createTransport(
        url: url,
        config: config,
        metrics: _metrics,
        onReply: _onReply,
        onDisconnect: _onDisconnected,
      );
      //  ..onReply = _onReply
      //  ..onDisconnect = () => _onDisconnected().ignore();

      // Prepare connect request.
      final SpinifyConnectRequest request;
      {
        final token = await config.getToken?.call();
        assert(token == null || token.length > 5, 'Spinify JWT is too short');
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

      final reply = await _sendCommand<SpinifyConnectResult>(request);

      if (!state.isConnecting)
        throw const SpinifyConnectionException(
          message: 'Connection is not in connecting state',
        );

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
        const SpinifyLogLevel.config(),
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
        const SpinifyLogLevel.error(),
        'connect_error',
        'Error connecting to server $url',
        <String, Object?>{
          'url': url,
          'error': error,
          'stackTrace': stackTrace,
        },
      );

      _transport?.disconnect().ignore();

      switch (error) {
        case SpinifyErrorResult result:
          if (result.code == 109) {
            // Token expired error.
            _setUpReconnectTimer(); // Retry resubscribe
          } else if (result.temporary) {
            // Temporary error.
            _setUpReconnectTimer(); // Retry resubscribe
          } else {
            // Disable resubscribe timer
            //moveToUnsubscribed(result.code, result.message, false);
            _setState(SpinifyState$Disconnected());
          }
        case SpinifyConnectionException _:
          _setUpReconnectTimer(); // Some spinify exception - retry resubscribe
          rethrow;
        default:
          _setUpReconnectTimer(); // Unknown error - retry resubscribe
      }

      Error.throwWithStackTrace(
        SpinifyConnectionException(
          message: 'Error connecting to server $url',
          error: error,
        ),
        stackTrace,
      );
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
      _refreshTimer = Timer(duration, () async {
        if (!state.isConnected) return;
        final token = await config.getToken?.call();
        if (token == null || token.isEmpty) {
          assert(token == null || token.length > 5, 'Spinify JWT is too short');
          config.logger?.call(
            const SpinifyLogLevel.warning(),
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

  @override
  Future<void> _onConnected() async {
    await super._onConnected();
    _tearDownReconnectTimer();
    _metrics.lastConnectAt = DateTime.now();
    _metrics.connects++;
  }

  void _setUpReconnectTimer() {
    _reconnectTimer?.cancel();
    final lastUrl = _metrics.reconnectUrl;
    if (lastUrl == null) return;
    final attempt = _metrics.reconnectAttempts ?? 0;
    final delay = Backoff.nextDelay(
      attempt,
      config.connectionRetryInterval.min.inMilliseconds,
      config.connectionRetryInterval.max.inMilliseconds,
    );
    _metrics.reconnectAttempts = attempt + 1;
    if (delay <= Duration.zero) {
      if (!state.isDisconnected) return;
      config.logger?.call(
        const SpinifyLogLevel.config(),
        'reconnect_attempt',
        'Reconnecting to $lastUrl immediately.',
        {
          'url': lastUrl,
          'delay': delay,
        },
      );
      Future<void>.sync(() => connect(lastUrl)).ignore();
      return;
    }
    config.logger?.call(
      const SpinifyLogLevel.debug(),
      'reconnect_delayed',
      'Setting up reconnect timer to $lastUrl '
          'after ${delay.inMilliseconds} ms.',
      {
        'url': lastUrl,
        'delay': delay,
      },
    );
    _metrics.nextReconnectAt = DateTime.now().add(delay);
    _reconnectTimer = Timer(
      delay,
      () {
        //_nextReconnectionAttempt = null;
        if (!state.isDisconnected) return;
        config.logger?.call(
          const SpinifyLogLevel.config(),
          'reconnect_attempt',
          'Reconnecting to $lastUrl after ${delay.inMilliseconds} ms.',
          {
            'url': lastUrl,
            'delay': delay,
          },
        );
        Future<void>.sync(() => connect(lastUrl)).ignore();
      },
    );
    //connect(_reconnectUrl!);
  }

  void _tearDownReconnectTimer() {
    _metrics
      ..reconnectAttempts = null
      ..nextReconnectAt = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  @override
  Future<void> ready() async {
    if (state.isConnected) return;
    if (state.isClosed)
      throw const SpinifyConnectionException(
        message: 'Connection is closed permanently',
      );
    return (_readyCompleter ??= Completer<void>()).future;
  }

  @override
  Future<void> disconnect() async {
    // Disable reconnect because we are disconnecting manually/intentionally.
    _metrics.reconnectUrl = null;
    _tearDownReconnectTimer();
    if (state.isDisconnected) return Future.value();
    await _transport?.disconnect(1000, 'disconnected by client');
    await _onDisconnected();
  }

  @override
  Future<void> _onDisconnected() async {
    _refreshTimer?.cancel();
    _transport = null;
    // Reconnect if that callback called not from disconnect method.
    if (_metrics.reconnectUrl != null) _setUpReconnectTimer();
    if (state.isConnected || state.isConnecting) {
      _metrics.lastDisconnectAt = DateTime.now();
      _metrics.disconnects++;
    }
    await super._onDisconnected();
  }

  @override
  Future<void> _onReply(SpinifyReply reply) async {
    await super._onReply(reply);
    if (reply
        case SpinifyPush(
          event: SpinifyDisconnect(:String reason, :bool reconnect)
        )) {
      if (reconnect) {
        // Disconnect client temporarily.
        await _transport?.disconnect(1000, reason);
        await _onDisconnected();
      } else {
        // Disconnect client permanently.
        await disconnect();
      }
    }
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
  Future<void> ping() => _doOnReady(
        () => _sendCommand<SpinifyPingResult>(
          SpinifyPingRequest(timestamp: DateTime.now()),
        ),
      ); */

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
              const SpinifyLogLevel.warning(),
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
    if (!reply.isResult && reply is SpinifyServerPing) {
      final command = SpinifyPingRequest(timestamp: DateTime.now());
      await _sendCommandAsync(command);
      config.logger?.call(
        const SpinifyLogLevel.debug(),
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

/// Base mixin for Spinify client publications management.
base mixin SpinifyPublicationsMixin on SpinifyBase, SpinifyCommandMixin {
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
}

/// Base mixin for Spinify client presence management.
base mixin SpinifyPresenceMixin on SpinifyBase, SpinifyCommandMixin {
  @override
  Future<Map<String, SpinifyClientInfo>> presence(String channel) =>
      getSubscription(channel)?.presence() ??
      Future.error(
        SpinifySubscriptionException(
          channel: channel,
          message: 'Subscription not found',
        ),
        StackTrace.current,
      );

  @override
  Future<SpinifyPresenceStats> presenceStats(String channel) =>
      getSubscription(channel)?.presenceStats() ??
      Future.error(
        SpinifySubscriptionException(
          channel: channel,
          message: 'Subscription not found',
        ),
        StackTrace.current,
      );
}

/// Base mixin for Spinify client history management.
base mixin SpinifyHistoryMixin on SpinifyBase, SpinifyCommandMixin {
  @override
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
}

/// Base mixin for Spinify client RPC management.
base mixin SpinifyRPCMixin on SpinifyBase, SpinifyCommandMixin {
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
}

/// Base mixin for Spinify client metrics management.
base mixin SpinifyMetricsMixin on SpinifyBase {
  @override
  SpinifyMetrics get metrics => _metrics.freeze();
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
        SpinifySubscriptionMixin,
        SpinifyConnectionMixin,
        SpinifyPingPongMixin,
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
}

/// Wrapper for Spinify client subscriptions that allow to
/// send commands through the client.
@internal
extension type SpinifySubClient(SpinifyCommandMixin _commandSender)
    implements ISpinify {
  /// Build and send command to the server.
  @internal
  Future<T> sendCommand<T extends SpinifyReply>(
    SpinifyCommand Function(int nextId) builder,
  ) =>
      _commandSender._doOnReady(
        () => _commandSender._sendCommand<T>(
          builder(
            _commandSender._getNextCommandId(),
          ),
        ),
      );
}
