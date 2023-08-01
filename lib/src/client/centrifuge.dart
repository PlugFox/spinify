import 'dart:async';

import 'package:centrifuge_dart/src/client/centrifuge_interface.dart';
import 'package:centrifuge_dart/src/client/config.dart';
import 'package:centrifuge_dart/src/client/disconnect_code.dart';
import 'package:centrifuge_dart/src/client/state.dart';
import 'package:centrifuge_dart/src/client/states_stream.dart';
import 'package:centrifuge_dart/src/model/channel_presence.dart';
import 'package:centrifuge_dart/src/model/channel_push.dart';
import 'package:centrifuge_dart/src/model/event.dart';
import 'package:centrifuge_dart/src/model/exception.dart';
import 'package:centrifuge_dart/src/model/presence.dart';
import 'package:centrifuge_dart/src/model/presence_stats.dart';
import 'package:centrifuge_dart/src/model/publication.dart';
import 'package:centrifuge_dart/src/model/pushes_stream.dart';
import 'package:centrifuge_dart/src/subscription/client_subscription_manager.dart';
import 'package:centrifuge_dart/src/subscription/subscription.dart';
import 'package:centrifuge_dart/src/subscription/subscription_config.dart';
import 'package:centrifuge_dart/src/transport/transport_interface.dart';
import 'package:centrifuge_dart/src/transport/ws_protobuf_transport.dart';
import 'package:centrifuge_dart/src/util/event_queue.dart';
import 'package:centrifuge_dart/src/util/logger.dart' as logger;
import 'package:meta/meta.dart';
import 'package:stack_trace/stack_trace.dart' as st;

/// {@template centrifuge}
/// Centrifuge client.
/// {@endtemplate}
final class Centrifuge extends CentrifugeBase
    with
        CentrifugeEventReceiverMixin,
        CentrifugeErrorsMixin,
        CentrifugeStateMixin,
        CentrifugeConnectionMixin,
        CentrifugeSendMixin,
        CentrifugeClientSubscriptionMixin,
        CentrifugePublicationsMixin,
        CentrifugePresenceMixin,
        CentrifugeQueueMixin {
  /// {@macro centrifuge}
  Centrifuge([CentrifugeConfig? config])
      : super(config ?? CentrifugeConfig.byDefault());

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
  CentrifugeBase(CentrifugeConfig config) : _config = config {
    _transport = CentrifugeWSPBTransport(
      config: config,
    );
    _initCentrifuge();
  }

  /// Internal transport responsible
  /// for sending, receiving, encoding and decoding data from the server.
  /// {@nodoc}
  @nonVirtual
  late final ICentrifugeTransport _transport;

  /// Centrifuge config.
  /// {@nodoc}
  @nonVirtual
  final CentrifugeConfig _config;

  /// Manager responsible for client-side subscriptions.
  /// {@nodoc}
  late final ClientSubscriptionManager _clientSubscriptionManager =
      ClientSubscriptionManager(_transport);

  /// Init centrifuge client, override this method to add custom logic.
  /// This method is called in constructor.
  /// {@nodoc}
  @protected
  @mustCallSuper
  void _initCentrifuge() {}

  /// Called when connection established.
  /// Right before [CentrifugeState$Connected] state.
  /// {@nodoc}
  @protected
  @mustCallSuper
  void _onConnected(CentrifugeState$Connected state) {
    logger.fine('Connection established');
  }

  /// Called when connection lost.
  /// Right before [CentrifugeState$Disconnected] state.
  /// {@nodoc}
  @protected
  @mustCallSuper
  void _onDisconnected(CentrifugeState$Disconnected state) {
    logger.fine('Connection lost');
  }

  @override
  @mustCallSuper
  Future<void> close() async {}
}

/// Mixin responsible for event receiving and distribution by controllers
/// and streams to subscribers.
/// {@nodoc}
base mixin CentrifugeEventReceiverMixin on CentrifugeBase {
  @protected
  @nonVirtual
  final StreamController<CentrifugeChannelPush> _pushController =
      StreamController<CentrifugeChannelPush>.broadcast();

  @protected
  @nonVirtual
  final StreamController<CentrifugePublication> _publicationsController =
      StreamController<CentrifugePublication>.broadcast();

  @protected
  @nonVirtual
  final StreamController<CentrifugeJoin> _joinController =
      StreamController<CentrifugeJoin>.broadcast();

  @protected
  @nonVirtual
  final StreamController<CentrifugeLeave> _leaveController =
      StreamController<CentrifugeLeave>.broadcast();

  @protected
  @nonVirtual
  final StreamController<CentrifugeChannelPresence> _presenceController =
      StreamController<CentrifugeChannelPresence>.broadcast();

  @override
  @nonVirtual
  late final CentrifugePushesStream stream = CentrifugePushesStream(
    pushes: _pushController.stream,
    publications: _publicationsController.stream,
    presenceEvents: _presenceController.stream,
    joinEvents: _joinController.stream,
    leaveEvents: _leaveController.stream,
  );

  @override
  void _initCentrifuge() {
    _transport.events.addListener(_onEvent);
    super._initCentrifuge();
  }

  /// Router for all events.
  /// {@nodoc}
  @protected
  @nonVirtual
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  void _onEvent(CentrifugeEvent event) {
    if (event is! CentrifugeChannelPush) return;
    // This is a push to a channel.
    _clientSubscriptionManager.onPush(event);
    _pushController.add(event);
    switch (event) {
      case CentrifugePublication publication:
        _publicationsController.add(publication);
      case CentrifugeJoin join:
        _presenceController.add(join);
        _joinController.add(join);
      case CentrifugeLeave leave:
        _presenceController.add(leave);
        _leaveController.add(leave);
    }
  }

  @override
  Future<void> close() async {
    await super.close();
    _transport.events.removeListener(_onEvent);
    for (final controller in <StreamSink<CentrifugeEvent>>[
      _pushController,
      _publicationsController,
      _joinController,
      _leaveController,
      _presenceController,
    ]) {
      controller.close().ignore();
    }
  }
}

/// Mixin responsible for centrifuge states
/// {@nodoc}
@internal
base mixin CentrifugeStateMixin on CentrifugeBase, CentrifugeErrorsMixin {
  /// Refresh timer.
  /// {@nodoc}
  Timer? _refreshTimer;

  @override
  @nonVirtual
  CentrifugeState get state => _state;

  @nonVirtual
  @protected
  late CentrifugeState _state;

  @override
  @nonVirtual
  late final CentrifugeStatesStream states =
      CentrifugeStatesStream(_statesController.stream);

  @override
  void _initCentrifuge() {
    _state = _transport.state;
    _transport.states.addListener(_onStateChange);
    super._initCentrifuge();
  }

  @protected
  @nonVirtual
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  void _onStateChange(CentrifugeState newState) {
    logger.info('State changed: ${_state.type} -> ${state.type}');
    _refreshTimer?.cancel();
    _refreshTimer = null;
    switch (newState) {
      case CentrifugeState$Disconnected state:
        _onDisconnected(state);
      case CentrifugeState$Connecting _:
        break;
      case CentrifugeState$Connected state:
        _onConnected(state);
        if (state.expires == true) _setRefreshTimer(state.ttl);
      case CentrifugeState$Closed _:
        break;
    }
    _statesController.add(_state = newState);
  }

  @protected
  @nonVirtual
  final StreamController<CentrifugeState> _statesController =
      StreamController<CentrifugeState>.broadcast();

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
            CentrifugeRefreshException(
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
base mixin CentrifugeErrorsMixin on CentrifugeBase {
  @protected
  @nonVirtual
  void _emitError(CentrifugeException exception, StackTrace stackTrace) =>
      _errorsController.add(
        (
          exception: exception,
          stackTrace: st.Trace.from(stackTrace).terse,
        ),
      );

  late final StreamController<
          ({CentrifugeException exception, StackTrace stackTrace})>
      _errorsController = StreamController<
          ({CentrifugeException exception, StackTrace stackTrace})>.broadcast();

  @override
  late final Stream<({CentrifugeException exception, StackTrace stackTrace})>
      errors = _errorsController.stream;

  @override
  Future<void> close() async {
    await super.close();
    _errorsController.close().ignore();
  }
}

/// Mixin responsible for connection.
/// {@nodoc}
@internal
base mixin CentrifugeConnectionMixin
    on CentrifugeBase, CentrifugeErrorsMixin, CentrifugeStateMixin {
  @override
  Future<void> connect(String url) async {
    logger.fine('Interactively connecting to $url');
    try {
      _refreshTimer?.cancel();
      _refreshTimer = null;
      await _transport.connect(url);
    } on CentrifugeException catch (error, stackTrace) {
      _emitError(error, stackTrace);
      rethrow;
    } on Object catch (error, stackTrace) {
      final centrifugeException = CentrifugeConnectionException(
        message: 'Error while connecting to $url',
        error: error,
      );
      _emitError(centrifugeException, stackTrace);
      Error.throwWithStackTrace(centrifugeException, stackTrace);
    }
  }

  @override
  FutureOr<void> ready() async {
    try {
      switch (state) {
        case CentrifugeState$Disconnected _:
          throw const CentrifugeConnectionException(
            message: 'Client is not connected',
          );
        case CentrifugeState$Closed _:
          throw const CentrifugeConnectionException(
            message: 'Client is permanently closed',
          );
        case CentrifugeState$Connected _:
          return;
        case CentrifugeState$Connecting _:
          await states.connected.first.timeout(_config.timeout);
      }
    } on TimeoutException catch (error, stackTrace) {
      _transport
          .disconnect(
            DisconnectCode.timeout.code,
            DisconnectCode.timeout.reason,
          )
          .ignore();
      final centrifugeException = CentrifugeConnectionException(
        message: 'Timeout exception while waiting for connection',
        error: error,
      );
      _emitError(centrifugeException, stackTrace);
      Error.throwWithStackTrace(centrifugeException, stackTrace);
    } on CentrifugeException catch (error, stackTrace) {
      _emitError(error, stackTrace);
      rethrow;
    } on Object catch (error, stackTrace) {
      final centrifugeException = CentrifugeConnectionException(
        message: 'Client is not connected',
        error: error,
      );
      _emitError(centrifugeException, stackTrace);
      Error.throwWithStackTrace(centrifugeException, stackTrace);
    }
  }

  @override
  Future<void> disconnect() async {
    logger.fine('Interactively disconnecting');
    try {
      await _transport.disconnect(0, 'Disconnect called');
    } on CentrifugeException catch (error, stackTrace) {
      _emitError(error, stackTrace);
      rethrow;
    } on Object catch (error, stackTrace) {
      final centrifugeException = CentrifugeConnectionException(
        message: 'Error while disconnecting',
        error: error,
      );
      _emitError(centrifugeException, stackTrace);
      Error.throwWithStackTrace(centrifugeException, stackTrace);
    }
  }

  @override
  Future<void> close() async {
    logger.fine('Interactively closing');
    await super.close();
    await _transport.close();
  }
}

/// Mixin responsible for sending asynchronous messages.
/// {@nodoc}
@internal
base mixin CentrifugeSendMixin on CentrifugeBase, CentrifugeErrorsMixin {
  @override
  Future<void> send(List<int> data) async {
    try {
      await ready();
      await _transport.sendAsyncMessage(data);
    } on CentrifugeException catch (error, stackTrace) {
      _emitError(error, stackTrace);
      rethrow;
    } on Object catch (error, stackTrace) {
      final centrifugeException = CentrifugeSendException(error: error);
      _emitError(centrifugeException, stackTrace);
      Error.throwWithStackTrace(centrifugeException, stackTrace);
    }
  }
}

/// Mixin responsible for client-side subscriptions.
/// {@nodoc}
@internal
base mixin CentrifugeClientSubscriptionMixin
    on CentrifugeBase, CentrifugeErrorsMixin {
  @override
  CentrifugeClientSubscription newSubscription(
    String channel, [
    CentrifugeSubscriptionConfig? config,
  ]) =>
      _clientSubscriptionManager.newSubscription(channel, config);

  @override
  Map<String, CentrifugeClientSubscription> get subscriptions =>
      _clientSubscriptionManager.subscriptions;

  @override
  CentrifugeClientSubscription? getSubscription(String channel) =>
      _clientSubscriptionManager[channel];

  @override
  Future<void> removeSubscription(
    CentrifugeClientSubscription subscription,
  ) async {
    try {
      await _clientSubscriptionManager.removeSubscription(subscription);
    } on CentrifugeException catch (error, stackTrace) {
      _emitError(error, stackTrace);
      rethrow;
    } on Object catch (error, stackTrace) {
      final centrifugeException = CentrifugeSubscriptionException(
        channel: subscription.channel,
        message: 'Error while unsubscribing',
        error: error,
      );
      _emitError(centrifugeException, stackTrace);
      Error.throwWithStackTrace(centrifugeException, stackTrace);
    }
  }

  @override
  void _onConnected(CentrifugeState$Connected state) {
    super._onConnected(state);
    _clientSubscriptionManager.subscribeAll();
  }

  @override
  void _onDisconnected(CentrifugeState$Disconnected state) {
    super._onDisconnected(state);
    _clientSubscriptionManager.unsubscribeAll();
  }

  @override
  Future<void> close() async {
    await super.close();
    _clientSubscriptionManager.removeAll();
  }
}

/// Mixin responsible for client-side subscriptions.
/// {@nodoc}
@internal
base mixin CentrifugePublicationsMixin
    on
        CentrifugeBase,
        CentrifugeErrorsMixin,
        CentrifugeClientSubscriptionMixin {
  @override
  Future<void> publish(String channel, List<int> data) async {
    try {
      await ready();
      await _transport.publish(channel, data);
    } on CentrifugeException catch (error, stackTrace) {
      _emitError(error, stackTrace);
      rethrow;
    } on Object catch (error, stackTrace) {
      final centrifugeException = CentrifugeSendException(
        message: 'Error while publishing to channel $channel',
        error: error,
      );
      _emitError(centrifugeException, stackTrace);
      Error.throwWithStackTrace(centrifugeException, stackTrace);
    }
  }
}

/// Mixin responsible for presence.
/// {@nodoc}
base mixin CentrifugePresenceMixin
    on
        CentrifugeBase,
        CentrifugeErrorsMixin,
        CentrifugeClientSubscriptionMixin {
  @override
  Future<CentrifugePresence> presence(String channel) async {
    try {
      await ready();
      return await _transport.presence(channel);
    } on CentrifugeException catch (error, stackTrace) {
      _emitError(error, stackTrace);
      rethrow;
    } on Object catch (error, stackTrace) {
      final centrifugeException = CentrifugeFetchException(
        message: 'Error while fetching presence for channel $channel',
        error: error,
      );
      _emitError(centrifugeException, stackTrace);
      Error.throwWithStackTrace(centrifugeException, stackTrace);
    }
  }

  @override
  Future<CentrifugePresenceStats> presenceStats(String channel) async {
    try {
      await ready();
      return await _transport.presenceStats(channel);
    } on CentrifugeException catch (error, stackTrace) {
      _emitError(error, stackTrace);
      rethrow;
    } on Object catch (error, stackTrace) {
      final centrifugeException = CentrifugeFetchException(
        message: 'Error while fetching presence for channel $channel',
        error: error,
      );
      _emitError(centrifugeException, stackTrace);
      Error.throwWithStackTrace(centrifugeException, stackTrace);
    }
  }
}

/// Mixin responsible for queue.
/// SHOULD BE LAST MIXIN.
/// {@nodoc}
@internal
base mixin CentrifugeQueueMixin on CentrifugeBase {
  /// {@nodoc}
  final CentrifugeEventQueue _eventQueue = CentrifugeEventQueue();

  @override
  Future<void> connect(String url) =>
      _eventQueue.push<void>('connect', () => super.connect(url));

  @override
  Future<void> publish(String channel, List<int> data) =>
      _eventQueue.push<void>('publish', () => super.publish(channel, data));

  @override
  FutureOr<void> ready() => _eventQueue.push<void>('ready', super.ready);

  @override
  Future<CentrifugePresence> presence(String channel) =>
      _eventQueue.push<CentrifugePresence>(
        'presence',
        () => super.presence(channel),
      );

  @override
  Future<CentrifugePresenceStats> presenceStats(String channel) =>
      _eventQueue.push<CentrifugePresenceStats>(
        'presenceStats',
        () => super.presenceStats(channel),
      );

  @override
  Future<void> disconnect() =>
      _eventQueue.push<void>('disconnect', super.disconnect);

  @override
  Future<void> close() => _eventQueue
      .push<void>('close', super.close)
      .whenComplete(_eventQueue.close);
}
