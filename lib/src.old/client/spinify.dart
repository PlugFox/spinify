import 'dart:async';

import 'package:meta/meta.dart';

import '../model/channel_presence.dart';
import '../model/channel_push.dart';
import '../model/connect.dart';
import '../model/disconnect.dart';
import '../model/event.dart';
import '../model/exception.dart';
import '../model/history.dart';
import '../model/message.dart';
import '../model/metrics.dart';
import '../model/presence.dart';
import '../model/presence_stats.dart';
import '../model/publication.dart';
import '../model/pushes_stream.dart';
import '../model/refresh.dart';
import '../model/stream_position.dart';
import '../model/subscribe.dart';
import '../model/unsubscribe.dart';
import '../subscription/client_subscription_manager.dart';
import '../subscription/server_subscription_manager.dart';
import '../subscription/subscription.dart';
import '../subscription/subscription_config.dart';
import '../transport/transport_interface.dart';
import '../transport/ws_protobuf_transport.dart';
import '../util/event_queue.dart';
import '../util/logger.dart' as logger;
import 'config.dart';
import 'disconnect_code.dart';
import 'observer.dart';
import 'spinify_interface.dart';
import 'state.dart';
import 'states_stream.dart';

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
        SpinifyErrorsMixin,
        SpinifyStateMixin,
        SpinifyEventReceiverMixin,
        SpinifyConnectionMixin,
        SpinifySendMixin,
        SpinifyClientSubscriptionMixin,
        SpinifyServerSubscriptionMixin,
        SpinifyPublicationsMixin,
        SpinifyPresenceMixin,
        SpinifyHistoryMixin,
        SpinifyRPCMixin,
        SpinifyQueueMixin,
        SpinifyMetricsMixin {
  /// {@macro spinify}
  Spinify([SpinifyConfig? config]) : super(config ?? SpinifyConfig.byDefault());

  /// Create client and connect.
  ///
  /// {@macro spinify}
  factory Spinify.connect(String url, [SpinifyConfig? config]) =>
      Spinify(config)..connect(url);

  /// The current [SpinifyObserver] instance.
  static SpinifyObserver? observer;
}

/// Base class for Spinify client.
abstract base class SpinifyBase implements ISpinify {
  /// Create a new Spinify client.
  SpinifyBase(SpinifyConfig config) : _config = config {
    _transport = SpinifyWSPBTransport(
      config: config,
    );
    _initSpinify();
  }

  /// Internal transport responsible
  /// for sending, receiving, encoding and decoding data from the server.
  @nonVirtual
  late final ISpinifyTransport _transport;

  /// Spinify config.
  @nonVirtual
  final SpinifyConfig _config;

  /// Manager responsible for client-side subscriptions.
  late final ClientSubscriptionManager _clientSubscriptionManager =
      ClientSubscriptionManager(_transport);

  /// Manager responsible for client-side subscriptions.
  late final ServerSubscriptionManager _serverSubscriptionManager =
      ServerSubscriptionManager(_transport);

  @override
  ({
    Map<String, SpinifyClientSubscription> client,
    Map<String, SpinifyServerSubscription> server,
  }) get subscriptions => (
        client: _clientSubscriptionManager.subscriptions,
        server: _serverSubscriptionManager.subscriptions
      );

  /// Init spinify client, override this method to add custom logic.
  /// This method is called in constructor.
  @protected
  @mustCallSuper
  void _initSpinify() {
    logger.fine('Spinify client initialized');
    Spinify.observer?.onCreate(this);
  }

  /// Called when connection established.
  /// Right before [SpinifyState$Connected] state.
  @protected
  @mustCallSuper
  void _onConnected(SpinifyState$Connected state) {
    logger.fine('Connection established');
    Spinify.observer?.onConnected(this, state);
  }

  /// Called when connection lost.
  /// Right before [SpinifyState$Disconnected] state.
  @protected
  @mustCallSuper
  void _onDisconnected(SpinifyState$Disconnected state) {
    logger.fine('Connection lost');
    Spinify.observer?.onDisconnected(this, state);
  }

  @override
  @mustCallSuper
  Future<void> close() async {
    await _transport.close();
    logger.fine('Spinify client closed');
    Spinify.observer?.onClose(this);
  }

  @override
  String toString() => 'Spinify{}';
}

/// Mixin responsible for event receiving and distribution by controllers
/// and streams to subscribers.
base mixin SpinifyEventReceiverMixin on SpinifyBase, SpinifyStateMixin {
  @protected
  @nonVirtual
  final StreamController<SpinifyChannelPush> _pushController =
      StreamController<SpinifyChannelPush>.broadcast();

  @protected
  @nonVirtual
  final StreamController<SpinifyPublication> _publicationsController =
      StreamController<SpinifyPublication>.broadcast();

  @protected
  @nonVirtual
  final StreamController<SpinifyMessage> _messagesController =
      StreamController<SpinifyMessage>.broadcast();

  @protected
  @nonVirtual
  final StreamController<SpinifyJoin> _joinController =
      StreamController<SpinifyJoin>.broadcast();

  @protected
  @nonVirtual
  final StreamController<SpinifyLeave> _leaveController =
      StreamController<SpinifyLeave>.broadcast();

  @protected
  @nonVirtual
  final StreamController<SpinifyChannelPresence> _presenceController =
      StreamController<SpinifyChannelPresence>.broadcast();

  @override
  @nonVirtual
  late final SpinifyPushesStream stream = SpinifyPushesStream(
    pushes: _pushController.stream,
    publications: _publicationsController.stream,
    messages: _messagesController.stream,
    presenceEvents: _presenceController.stream,
    joinEvents: _joinController.stream,
    leaveEvents: _leaveController.stream,
  );

  @override
  void _initSpinify() {
    _transport.events.addListener(_onEvent);
    super._initSpinify();
  }

  /// Router for all events.
  @protected
  @nonVirtual
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  void _onEvent(SpinifyEvent event) {
    Spinify.observer?.onEvent(this, event);
    if (event is! SpinifyChannelPush) return;
    // This is a push to a channel.
    _clientSubscriptionManager.onPush(event);
    _pushController.add(event);
    switch (event) {
      case SpinifyPublication publication:
        logger.fine(
            'Publication event received for channel ${publication.channel}');
        _publicationsController.add(publication);
      case SpinifyMessage message:
        logger.fine('Message event received for channel ${message.channel}');
        _messagesController.add(message);
      case SpinifyJoin join:
        logger.fine('Join event received for channel ${join.channel} '
            'and user ${join.info.user}');
        _presenceController.add(join);
        _joinController.add(join);
      case SpinifyLeave leave:
        logger.fine('Leave event received for channel ${leave.channel} '
            'and user ${leave.info.user}');
        _presenceController.add(leave);
        _leaveController.add(leave);
      case SpinifySubscribe subscribe:
        _serverSubscriptionManager.subscribe(subscribe);
      case SpinifyUnsubscribe unsubscribe:
        _serverSubscriptionManager.unsubscribe(unsubscribe);
      case SpinifyConnect _:
        break;
      case SpinifyDisconnect event:
        final code = event.code;
        final reconnect =
            code < 3500 || code >= 5000 || (code >= 4000 && code < 4500);
        if (reconnect) {
          logger.fine('Disconnect transport by server push '
              'and reconnect after backoff delay');
          _transport.disconnect(code, event.reason).ignore();
        } else {
          logger
              .fine('Disconnect interactive by server push, without reconnect');
          disconnect().ignore();
        }
        break;
      case SpinifyRefresh _:
        logger.fine('Refresh connection token by server push');
        _refreshToken();
        break;
    }
  }

  @override
  Future<void> close() async {
    await super.close();
    _transport.events.removeListener(_onEvent);
    for (final controller in <StreamSink<SpinifyEvent>>[
      _pushController,
      _publicationsController,
      _messagesController,
      _joinController,
      _leaveController,
      _presenceController,
    ]) {
      controller.close().ignore();
    }
  }
}

/// Mixin responsible for spinify states
base mixin SpinifyStateMixin on SpinifyBase, SpinifyErrorsMixin {
  /// Refresh timer.
  Timer? _refreshTimer;

  @override
  @nonVirtual
  SpinifyState get state => _state;

  @nonVirtual
  @protected
  late SpinifyState _state;

  @override
  @nonVirtual
  late final SpinifyStatesStream states =
      SpinifyStatesStream(_statesController.stream);

  @override
  void _initSpinify() {
    _state = _transport.state;
    _transport.states.addListener(_onStateChange);
    super._initSpinify();
  }

  @protected
  @nonVirtual
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  void _onStateChange(SpinifyState newState) {
    final oldState = _state;
    logger.info('State changed: ${oldState.type} -> ${newState.type}');
    _refreshTimer?.cancel();
    _refreshTimer = null;
    switch (newState) {
      case SpinifyState$Disconnected state:
        _onDisconnected(state);
      case SpinifyState$Connecting _:
        break;
      case SpinifyState$Connected state:
        _onConnected(state);
        if (state.expires == true) _setRefreshTimer(state.ttl);
      case SpinifyState$Closed _:
        break;
    }
    _statesController.add(_state = newState);
    Spinify.observer?.onStateChanged(this, oldState, newState);
  }

  @protected
  @nonVirtual
  final StreamController<SpinifyState> _statesController =
      StreamController<SpinifyState>.broadcast();

  /// Refresh connection token when ttl is expired.
  void _setRefreshTimer(DateTime? ttl) {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    if (ttl == null) return;
    final now = DateTime.now();
    final duration = ttl.subtract(_config.timeout * 4).difference(now);
    if (duration.isNegative) return;
    _refreshTimer = Timer(duration, _refreshToken);
  }

  /// Refresh token for subscription.
  void _refreshToken() => Future<void>(() async {
        try {
          _refreshTimer?.cancel();
          _refreshTimer = null;
          final token = await _config.getToken?.call();
          if (token == null || !state.isConnected) return;
          await _transport.sendRefresh(token);
        } on Object catch (error, stackTrace) {
          logger.warning(
            error,
            stackTrace,
            'Error while refreshing connection token',
          );
          _emitError(
            SpinifyRefreshException(
              message: 'Error while refreshing connection token',
              error: error,
            ),
            stackTrace,
          );
        }
      }).ignore();

  @override
  Future<void> close() => super.close().whenComplete(() {
        _transport.states.removeListener(_onStateChange);
        _statesController.close().ignore();
      });
}

/// Mixin responsible for errors stream.
base mixin SpinifyErrorsMixin on SpinifyBase {
  @protected
  @nonVirtual
  void _emitError(SpinifyException exception, StackTrace stackTrace) =>
      Spinify.observer?.onError(exception, stackTrace);
}

/// Mixin responsible for connection.
base mixin SpinifyConnectionMixin
    on SpinifyBase, SpinifyErrorsMixin, SpinifyStateMixin {
  @override
  Future<void> connect(String url) async {
    logger.fine('Interactively connecting to $url');
    try {
      _refreshTimer?.cancel();
      _refreshTimer = null;
      await _transport.connect(url, _serverSubscriptionManager);
    } on SpinifyException catch (error, stackTrace) {
      _emitError(error, stackTrace);
      rethrow;
    } on Object catch (error, stackTrace) {
      final spinifyException = SpinifyConnectionException(
        message: 'Error while connecting to $url',
        error: error,
      );
      _emitError(spinifyException, stackTrace);
      Error.throwWithStackTrace(spinifyException, stackTrace);
    }
  }

  @override
  FutureOr<void> ready() async {
    try {
      switch (state) {
        case SpinifyState$Disconnected _:
          throw const SpinifyConnectionException(
            message: 'Client is not connected',
          );
        case SpinifyState$Closed _:
          throw const SpinifyConnectionException(
            message: 'Client is permanently closed',
          );
        case SpinifyState$Connected _:
          return;
        case SpinifyState$Connecting _:
          await states.connected.first.timeout(_config.timeout);
      }
    } on TimeoutException catch (error, stackTrace) {
      _transport
          .disconnect(
            DisconnectCode.timeout.code,
            DisconnectCode.timeout.reason,
          )
          .ignore();
      final spinifyException = SpinifyConnectionException(
        message: 'Timeout exception while waiting for connection',
        error: error,
      );
      _emitError(spinifyException, stackTrace);
      Error.throwWithStackTrace(spinifyException, stackTrace);
    } on SpinifyException catch (error, stackTrace) {
      _emitError(error, stackTrace);
      rethrow;
    } on Object catch (error, stackTrace) {
      final spinifyException = SpinifyConnectionException(
        message: 'Client is not connected',
        error: error,
      );
      _emitError(spinifyException, stackTrace);
      Error.throwWithStackTrace(spinifyException, stackTrace);
    }
  }

  @override
  Future<void> disconnect([
    int code = 0,
    String reason = 'Disconnect called',
  ]) async {
    logger.fine('Interactively disconnecting');
    try {
      await _transport.disconnect(code, reason);
    } on SpinifyException catch (error, stackTrace) {
      _emitError(error, stackTrace);
      rethrow;
    } on Object catch (error, stackTrace) {
      final spinifyException = SpinifyConnectionException(
        message: 'Error while disconnecting',
        error: error,
      );
      _emitError(spinifyException, stackTrace);
      Error.throwWithStackTrace(spinifyException, stackTrace);
    }
  }

  @override
  Future<void> close() async {
    logger.fine('Interactively closing');
    await super.close();
  }
}

/// Mixin responsible for sending asynchronous messages.
base mixin SpinifySendMixin on SpinifyBase, SpinifyErrorsMixin {
  @override
  Future<void> send(List<int> data) async {
    try {
      await ready();
      await _transport.sendAsyncMessage(data);
    } on SpinifyException catch (error, stackTrace) {
      _emitError(error, stackTrace);
      rethrow;
    } on Object catch (error, stackTrace) {
      final spinifyException = SpinifySendException(error: error);
      _emitError(spinifyException, stackTrace);
      Error.throwWithStackTrace(spinifyException, stackTrace);
    }
  }
}

/// Mixin responsible for client-side subscriptions.
base mixin SpinifyClientSubscriptionMixin on SpinifyBase, SpinifyErrorsMixin {
  @override
  SpinifyClientSubscription newSubscription(
    String channel, [
    SpinifySubscriptionConfig? config,
  ]) {
    final sub = _clientSubscriptionManager[channel] ??
        _serverSubscriptionManager[channel];
    if (sub != null) {
      throw SpinifySubscriptionException(
        channel: channel,
        message: 'Subscription already exists',
      );
    }
    return _clientSubscriptionManager.newSubscription(channel, config);
  }

  @override
  SpinifyClientSubscription? getSubscription(String channel) =>
      _clientSubscriptionManager[channel];

  @override
  Future<void> removeSubscription(
    SpinifyClientSubscription subscription,
  ) async {
    try {
      await _clientSubscriptionManager.removeSubscription(subscription);
    } on SpinifyException catch (error, stackTrace) {
      _emitError(error, stackTrace);
      rethrow;
    } on Object catch (error, stackTrace) {
      final spinifyException = SpinifySubscriptionException(
        channel: subscription.channel,
        message: 'Error while unsubscribing',
        error: error,
      );
      _emitError(spinifyException, stackTrace);
      Error.throwWithStackTrace(spinifyException, stackTrace);
    }
  }

  @override
  void _onConnected(SpinifyState$Connected state) {
    super._onConnected(state);
    _clientSubscriptionManager.subscribeAll();
  }

  @override
  void _onDisconnected(SpinifyState$Disconnected state) {
    super._onDisconnected(state);
    _clientSubscriptionManager.unsubscribeAll();
  }

  @override
  Future<void> close() async {
    await super.close();
    _clientSubscriptionManager.close();
  }
}

/// Mixin responsible for server-side subscriptions.
base mixin SpinifyServerSubscriptionMixin on SpinifyBase {
  @override
  void _onConnected(SpinifyState$Connected state) {
    super._onConnected(state);
    _serverSubscriptionManager.setSubscribedAll();
  }

  @override
  void _onDisconnected(SpinifyState$Disconnected state) {
    super._onDisconnected(state);
    _serverSubscriptionManager.setSubscribingAll();
  }

  @override
  Future<void> close() async {
    await super.close();
    _serverSubscriptionManager.close();
  }
}

/// Mixin responsible for publications.
base mixin SpinifyPublicationsMixin
    on SpinifyBase, SpinifyErrorsMixin, SpinifyClientSubscriptionMixin {
  @override
  Future<void> publish(String channel, List<int> data) async {
    try {
      await ready();
      await _transport.publish(channel, data);
    } on SpinifyException catch (error, stackTrace) {
      _emitError(error, stackTrace);
      rethrow;
    } on Object catch (error, stackTrace) {
      final spinifyException = SpinifySendException(
        message: 'Error while publishing to channel $channel',
        error: error,
      );
      _emitError(spinifyException, stackTrace);
      Error.throwWithStackTrace(spinifyException, stackTrace);
    }
  }
}

/// Mixin responsible for presence.
base mixin SpinifyPresenceMixin on SpinifyBase, SpinifyErrorsMixin {
  @override
  Future<SpinifyPresence> presence(String channel) async {
    try {
      await ready();
      return await _transport.presence(channel);
    } on SpinifyException catch (error, stackTrace) {
      _emitError(error, stackTrace);
      rethrow;
    } on Object catch (error, stackTrace) {
      final spinifyException = SpinifyFetchException(
        message: 'Error while fetching presence for channel $channel',
        error: error,
      );
      _emitError(spinifyException, stackTrace);
      Error.throwWithStackTrace(spinifyException, stackTrace);
    }
  }

  @override
  Future<SpinifyPresenceStats> presenceStats(String channel) async {
    try {
      await ready();
      return await _transport.presenceStats(channel);
    } on SpinifyException catch (error, stackTrace) {
      _emitError(error, stackTrace);
      rethrow;
    } on Object catch (error, stackTrace) {
      final spinifyException = SpinifyFetchException(
        message: 'Error while fetching presence for channel $channel',
        error: error,
      );
      _emitError(spinifyException, stackTrace);
      Error.throwWithStackTrace(spinifyException, stackTrace);
    }
  }
}

/// Mixin responsible for history.
base mixin SpinifyHistoryMixin on SpinifyBase, SpinifyErrorsMixin {
  @override
  Future<SpinifyHistory> history(
    String channel, {
    int? limit,
    SpinifyStreamPosition? since,
    bool? reverse,
  }) async {
    try {
      await ready();
      return await _transport.history(
        channel,
        limit: limit,
        since: since,
        reverse: reverse,
      );
    } on SpinifyException catch (error, stackTrace) {
      _emitError(error, stackTrace);
      rethrow;
    } on Object catch (error, stackTrace) {
      final spinifyException = SpinifyFetchException(
        message: 'Error while fetching history for channel $channel',
        error: error,
      );
      _emitError(spinifyException, stackTrace);
      Error.throwWithStackTrace(spinifyException, stackTrace);
    }
  }
}

/// Mixin responsible for history.
base mixin SpinifyRPCMixin on SpinifyBase, SpinifyErrorsMixin {
  @override
  Future<List<int>> rpc(String method, List<int> data) async {
    try {
      await ready();
      return await _transport.rpc(method, data);
    } on SpinifyException catch (error, stackTrace) {
      _emitError(error, stackTrace);
      rethrow;
    } on Object catch (error, stackTrace) {
      final spinifyException = SpinifyFetchException(
        message: 'Error while remote procedure call for method $method',
        error: error,
      );
      _emitError(spinifyException, stackTrace);
      Error.throwWithStackTrace(spinifyException, stackTrace);
    }
  }
}

/// Responsible for metrics.
base mixin SpinifyMetricsMixin on SpinifyBase, SpinifyStateMixin {
  int _connectsTotal = 0, _connectsSuccessful = 0, _disconnects = 0;
  DateTime? _lastDisconnectTime, _lastConnectTime;
  ({int? code, String? reason})? _lastDisconnect;
  String? _lastUrl;
  late DateTime _initializedAt;

  @override
  void _initSpinify() {
    _initializedAt = DateTime.now().toUtc();
    super._initSpinify();
  }

  @override
  Future<void> connect(String url) async {
    _lastUrl = url;
    _connectsTotal++;
    return super.connect(url);
  }

  @override
  void _onConnected(SpinifyState$Connected state) {
    _lastConnectTime = DateTime.now().toUtc();
    _connectsSuccessful++;
    super._onConnected(state);
  }

  @override
  void _onDisconnected(SpinifyState$Disconnected state) {
    _lastDisconnectTime = DateTime.now().toUtc();
    _lastDisconnect = (code: state.closeCode, reason: state.closeReason);
    _disconnects = 0;
    super._onDisconnected(state);
  }

  /// Get metrics of Spinify client.
  @override
  SpinifyMetrics get metrics {
    final timestamp = DateTime.now().toUtc();
    return SpinifyMetrics(
      timestamp: timestamp,
      initializedAt: _initializedAt,
      lastUrl: _lastUrl,
      reconnects: (successful: _connectsSuccessful, total: _connectsTotal),
      subscriptions: (
        client: _clientSubscriptionManager.count,
        server: _serverSubscriptionManager.count,
      ),
      speed: _transport.speed,
      state: state,
      received: _transport.received,
      transferred: _transport.transferred,
      lastConnectTime: _lastConnectTime,
      lastDisconnectTime: _lastDisconnectTime,
      disconnects: _disconnects,
      lastDisconnect: _lastDisconnect,
      isRefreshActive: _refreshTimer?.isActive ?? false,
    );
  }
}

/// Mixin responsible for queue.
/// SHOULD BE LAST MIXIN.
base mixin SpinifyQueueMixin on SpinifyBase {
  final SpinifyEventQueue _eventQueue = SpinifyEventQueue();

  @override
  Future<void> connect(String url) =>
      _eventQueue.push<void>('connect', () => super.connect(url));

  @override
  Future<void> publish(String channel, List<int> data) =>
      _eventQueue.push<void>('publish', () => super.publish(channel, data));

  /* @override
  FutureOr<void> ready() => _eventQueue.push<void>('ready', super.ready); */

  @override
  Future<SpinifyPresence> presence(String channel) =>
      _eventQueue.push<SpinifyPresence>(
        'presence',
        () => super.presence(channel),
      );

  @override
  Future<SpinifyPresenceStats> presenceStats(String channel) =>
      _eventQueue.push<SpinifyPresenceStats>(
        'presenceStats',
        () => super.presenceStats(channel),
      );

  @override
  Future<SpinifyHistory> history(
    String channel, {
    int? limit,
    SpinifyStreamPosition? since,
    bool? reverse,
  }) =>
      _eventQueue.push<SpinifyHistory>(
        'history',
        () => super.history(
          channel,
          limit: limit,
          since: since,
          reverse: reverse,
        ),
      );

  @override
  Future<List<int>> rpc(String method, List<int> data) =>
      _eventQueue.push<List<int>>(
        'rpc',
        () => super.rpc(method, data),
      );

  @override
  Future<void> disconnect([
    int code = 0,
    String reason = 'Disconnect called',
  ]) =>
      _eventQueue.push<void>(
          'disconnect', () => super.disconnect(code, reason));

  @override
  Future<void> close() => _eventQueue
      .push<void>('close', super.close)
      .whenComplete(_eventQueue.close);
}
