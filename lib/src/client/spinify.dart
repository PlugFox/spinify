import 'dart:async';

import 'package:meta/meta.dart';
import 'package:spinify/src/client/config.dart';
import 'package:spinify/src/client/disconnect_code.dart';
import 'package:spinify/src/client/observer.dart';
import 'package:spinify/src/client/spinify_interface.dart';
import 'package:spinify/src/client/state.dart';
import 'package:spinify/src/client/states_stream.dart';
import 'package:spinify/src/model/channel_presence.dart';
import 'package:spinify/src/model/channel_push.dart';
import 'package:spinify/src/model/connect.dart';
import 'package:spinify/src/model/disconnect.dart';
import 'package:spinify/src/model/event.dart';
import 'package:spinify/src/model/exception.dart';
import 'package:spinify/src/model/history.dart';
import 'package:spinify/src/model/message.dart';
import 'package:spinify/src/model/presence.dart';
import 'package:spinify/src/model/presence_stats.dart';
import 'package:spinify/src/model/publication.dart';
import 'package:spinify/src/model/pushes_stream.dart';
import 'package:spinify/src/model/refresh.dart';
import 'package:spinify/src/model/stream_position.dart';
import 'package:spinify/src/model/subscribe.dart';
import 'package:spinify/src/model/unsubscribe.dart';
import 'package:spinify/src/subscription/client_subscription_manager.dart';
import 'package:spinify/src/subscription/server_subscription_manager.dart';
import 'package:spinify/src/subscription/subscription.dart';
import 'package:spinify/src/subscription/subscription_config.dart';
import 'package:spinify/src/transport/transport_interface.dart';
import 'package:spinify/src/transport/ws_protobuf_transport.dart';
import 'package:spinify/src/util/event_queue.dart';
import 'package:spinify/src/util/logger.dart' as logger;

/// {@template spinify}
/// Spinify client.
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
        SpinifyQueueMixin {
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

/// {@nodoc}
@internal
abstract base class SpinifyBase implements ISpinify {
  /// {@nodoc}
  SpinifyBase(SpinifyConfig config) : _config = config {
    _transport = SpinifyWSPBTransport(
      config: config,
    );
    _initSpinify();
  }

  /// Internal transport responsible
  /// for sending, receiving, encoding and decoding data from the server.
  /// {@nodoc}
  @nonVirtual
  late final ISpinifyTransport _transport;

  /// Spinify config.
  /// {@nodoc}
  @nonVirtual
  final SpinifyConfig _config;

  /// Manager responsible for client-side subscriptions.
  /// {@nodoc}
  late final ClientSubscriptionManager _clientSubscriptionManager =
      ClientSubscriptionManager(_transport);

  /// Manager responsible for client-side subscriptions.
  /// {@nodoc}
  late final ServerSubscriptionManager _serverSubscriptionManager =
      ServerSubscriptionManager(_transport);

  /// Init spinify client, override this method to add custom logic.
  /// This method is called in constructor.
  /// {@nodoc}
  @protected
  @mustCallSuper
  void _initSpinify() {
    logger.fine('Spinify client initialized');
    Spinify.observer?.onCreate(this);
  }

  /// Called when connection established.
  /// Right before [SpinifyState$Connected] state.
  /// {@nodoc}
  @protected
  @mustCallSuper
  void _onConnected(SpinifyState$Connected state) {
    logger.fine('Connection established');
    Spinify.observer?.onConnected(this, state);
  }

  /// Called when connection lost.
  /// Right before [SpinifyState$Disconnected] state.
  /// {@nodoc}
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
/// {@nodoc}
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
  /// {@nodoc}
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
/// {@nodoc}
@internal
base mixin SpinifyStateMixin on SpinifyBase, SpinifyErrorsMixin {
  /// Refresh timer.
  /// {@nodoc}
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
  /// {@nodoc}
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
  /// {@nodoc}
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
/// {@nodoc}
@internal
base mixin SpinifyErrorsMixin on SpinifyBase {
  @protected
  @nonVirtual
  void _emitError(SpinifyException exception, StackTrace stackTrace) =>
      Spinify.observer?.onError(exception, stackTrace);
}

/// Mixin responsible for connection.
/// {@nodoc}
@internal
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
/// {@nodoc}
@internal
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
/// {@nodoc}
@internal
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
  Map<String, SpinifyClientSubscription> get subscriptions =>
      _clientSubscriptionManager.subscriptions;

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
/// {@nodoc}
@internal
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
/// {@nodoc}
@internal
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
/// {@nodoc}
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
/// {@nodoc}
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
/// {@nodoc}
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

/// Mixin responsible for queue.
/// SHOULD BE LAST MIXIN.
/// {@nodoc}
@internal
base mixin SpinifyQueueMixin on SpinifyBase {
  /// {@nodoc}
  final SpinifyEventQueue _eventQueue = SpinifyEventQueue();

  @override
  Future<void> connect(String url) =>
      _eventQueue.push<void>('connect', () => super.connect(url));

  @override
  Future<void> publish(String channel, List<int> data) =>
      _eventQueue.push<void>('publish', () => super.publish(channel, data));

  @override
  FutureOr<void> ready() => _eventQueue.push<void>('ready', super.ready);

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
