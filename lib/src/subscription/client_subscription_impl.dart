import 'dart:async';

import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:meta/meta.dart';
import 'package:spinify/src/client/centrifuge.dart';
import 'package:spinify/src/client/disconnect_code.dart';
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
import 'package:spinify/src/subscription/subscription.dart';
import 'package:spinify/src/subscription/subscription_config.dart';
import 'package:spinify/src/subscription/subscription_state.dart';
import 'package:spinify/src/subscription/subscription_states_stream.dart';
import 'package:spinify/src/transport/transport_interface.dart';
import 'package:spinify/src/util/event_queue.dart';
import 'package:spinify/src/util/logger.dart' as logger;

/// Client-side subscription implementation.
/// {@nodoc}
@internal
final class CentrifugeClientSubscriptionImpl
    extends CentrifugeClientSubscriptionBase
    with
        CentrifugeClientSubscriptionEventReceiverMixin,
        CentrifugeClientSubscriptionErrorsMixin,
        CentrifugeClientSubscriptionSubscribeMixin,
        CentrifugeClientSubscriptionPublishingMixin,
        CentrifugeClientSubscriptionHistoryMixin,
        CentrifugeClientSubscriptionPresenceMixin,
        CentrifugeClientSubscriptionQueueMixin {
  /// {@nodoc}
  CentrifugeClientSubscriptionImpl({
    required super.channel,
    required super.transportWeakRef,
    CentrifugeSubscriptionConfig? config,
  }) : super(config: config ?? const CentrifugeSubscriptionConfig.byDefault());
}

/// {@nodoc}
@internal
abstract base class CentrifugeClientSubscriptionBase
    implements CentrifugeClientSubscription {
  /// {@nodoc}
  CentrifugeClientSubscriptionBase({
    required this.channel,
    required WeakReference<ISpinifyTransport> transportWeakRef,
    required CentrifugeSubscriptionConfig config,
  }) : _config = config {
    _transportWeakRef = transportWeakRef;
    _initSubscription();
  }

  @override
  final String channel;

  /// Offset of last received publication.
  late fixnum.Int64 _offset;

  @override
  CentrifugeStreamPosition? get since => switch (state.since?.epoch) {
        String epoch => (epoch: epoch, offset: _offset),
        _ => state.since,
      };

  /// Weak reference to transport.
  /// {@nodoc}
  @nonVirtual
  late final WeakReference<ISpinifyTransport> _transportWeakRef;

  /// Internal transport responsible
  /// for sending, receiving, encoding and decoding data from the server.
  /// {@nodoc}
  ISpinifyTransport get _transport => _transportWeakRef.target!;

  /// Subscription config.
  /// {@nodoc}
  final CentrifugeSubscriptionConfig _config;

  /// Init subscription.
  /// {@nodoc}
  @protected
  @mustCallSuper
  void _initSubscription() {
    _state = CentrifugeSubscriptionState.unsubscribed(
        since: _config.since, code: 0, reason: 'initial state');
    _offset = _config.since?.offset ?? fixnum.Int64.ZERO;
  }

  /// Subscription has 3 states:
  /// - `unsubscribed`
  /// - `subscribing`
  /// - `subscribed`
  /// {@nodoc}
  @override
  CentrifugeSubscriptionState get state => _state;
  late CentrifugeSubscriptionState _state;

  /// Stream of subscription states.
  /// {@nodoc}
  @override
  late final CentrifugeSubscriptionStateStream states =
      CentrifugeSubscriptionStateStream(_stateController.stream);

  /// States controller.
  /// {@nodoc}
  final StreamController<CentrifugeSubscriptionState> _stateController =
      StreamController<CentrifugeSubscriptionState>.broadcast();

  /// Set new state.
  /// {@nodoc}
  void _setState(CentrifugeSubscriptionState state) {
    if (_state == state) return;
    final previousState = _state;
    _stateController.add(_state = state);
    Spinify.observer?.onSubscriptionChanged(this, previousState, state);
  }

  /// Notify about new publication.
  /// {@nodoc}
  @nonVirtual
  void _handlePublication(CentrifugePublication publication) {
    final offset = publication.offset;
    if (offset != null && offset > _offset) _offset = offset;
  }

  /// {@nodoc}
  @internal
  @mustCallSuper
  Future<void> close([int code = 0, String reason = 'closed']) async {
    if (!_state.isUnsubscribed)
      _setState(CentrifugeSubscriptionState.unsubscribed(
        code: code,
        reason: reason,
        recoverable: false,
        since: since,
      ));
    _stateController.close().ignore();
  }
}

/// Mixin responsible for event receiving and distribution by controllers
/// and streams to subscribers.
/// {@nodoc}
base mixin CentrifugeClientSubscriptionEventReceiverMixin
    on CentrifugeClientSubscriptionBase {
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
  final StreamController<CentrifugeMessage> _messagesController =
      StreamController<CentrifugeMessage>.broadcast();

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
    messages: _messagesController.stream,
    presenceEvents: _presenceController.stream,
    joinEvents: _joinController.stream,
    leaveEvents: _leaveController.stream,
  );

  @override
  void _initSubscription() {
    super._initSubscription();
  }

  /// Handle push event from server for the specific channel.
  /// Called from `CentrifugeClientSubscriptionsManager.onPush`
  /// {@nodoc}
  @internal
  @nonVirtual
  void onPush(CentrifugeChannelPush push) {
    // This is a push to a channel.
    _pushController.add(push);
    switch (push) {
      case CentrifugePublication publication:
        _handlePublication(publication);
        _publicationsController.add(publication);
      case CentrifugeMessage message:
        _messagesController.add(message);
      case CentrifugeJoin join:
        _presenceController.add(join);
        _joinController.add(join);
      case CentrifugeLeave leave:
        _presenceController.add(leave);
        _leaveController.add(leave);
      case CentrifugeSubscribe _:
        break; // For server side subscriptions.
      case CentrifugeUnsubscribe _:
        break; // For server side subscriptions.
      case CentrifugeConnect _:
        break;
      case CentrifugeDisconnect _:
        break;
      case CentrifugeRefresh _:
        break;
    }
  }

  @override
  Future<void> close([int code = 0, String reason = 'closed']) async {
    await super.close(code, reason);
    for (final controller in <StreamSink<CentrifugeEvent>>[
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

/// Mixin responsible for errors stream.
/// {@nodoc}
@internal
base mixin CentrifugeClientSubscriptionErrorsMixin
    on CentrifugeClientSubscriptionBase {
  @protected
  @nonVirtual
  void _emitError(CentrifugeException exception, StackTrace stackTrace) =>
      Spinify.observer?.onError(exception, stackTrace);
}

/// Mixin responsible for subscribing.
/// {@nodoc}
@internal
base mixin CentrifugeClientSubscriptionSubscribeMixin
    on
        CentrifugeClientSubscriptionBase,
        CentrifugeClientSubscriptionErrorsMixin {
  /// Refresh timer.
  /// {@nodoc}
  Timer? _refreshTimer;

  /// Start subscribing to a channel
  /// {@nodoc}
  @override
  Future<void> subscribe() async {
    logger.fine('Subscribing to $channel');
    try {
      if (state.isSubscribed) {
        return;
      } else if (state.isSubscribing) {
        return await ready();
      }
      _refreshTimer?.cancel();
      _refreshTimer = null;
      _setState(CentrifugeSubscriptionState$Subscribing(
        since: since,
        recoverable: state.recoverable,
      ));
      final subscribed = await _transport.subscribe(
        channel,
        _config,
        switch (state.since) {
          null => null,
          ({String epoch, fixnum.Int64 offset}) s => (
              epoch: s.epoch,
              offset: _offset,
            ),
        },
      );
      final offset = subscribed.since?.offset;
      if (offset != null && offset > _offset) _offset = offset;
      _setState(CentrifugeSubscriptionState$Subscribed(
        since: subscribed.since ?? since,
        recoverable: subscribed.recoverable,
        ttl: subscribed.ttl,
      ));
      if (subscribed.publications.isNotEmpty)
        subscribed.publications.forEach(_handlePublication);
      if (subscribed.expires) _setRefreshTimer(subscribed.ttl);
    } on CentrifugeException catch (error, stackTrace) {
      unsubscribe(0, 'error while subscribing').ignore();
      _emitError(error, stackTrace);
      rethrow;
    } on Object catch (error, stackTrace) {
      unsubscribe(0, 'error while subscribing').ignore();
      final centrifugeException = CentrifugeSubscriptionException(
        message: 'Error while subscribing',
        channel: channel,
        error: error,
      );
      _emitError(centrifugeException, stackTrace);
      Error.throwWithStackTrace(centrifugeException, stackTrace);
    }
  }

  /// Await for subscription to be ready.
  /// {@nodoc}
  @override
  FutureOr<void> ready() async {
    try {
      switch (state) {
        case CentrifugeSubscriptionState$Unsubscribed _:
          throw CentrifugeSubscriptionException(
            message: 'Subscription is not subscribed',
            channel: channel,
          );
        case CentrifugeSubscriptionState$Subscribed _:
          return;
        case CentrifugeSubscriptionState$Subscribing _:
          await states.subscribed.first.timeout(_config.timeout);
      }
    } on TimeoutException catch (error, stackTrace) {
      _transport
          .disconnect(
            DisconnectCode.timeout.code,
            DisconnectCode.timeout.reason,
          )
          .ignore();
      final centrifugeException = CentrifugeSubscriptionException(
        message: 'Timeout exception while waiting for subscribing to $channel',
        channel: channel,
        error: error,
      );
      _emitError(centrifugeException, stackTrace);
      Error.throwWithStackTrace(centrifugeException, stackTrace);
    } on CentrifugeException catch (error, stackTrace) {
      _emitError(error, stackTrace);
      rethrow;
    } on Object catch (error, stackTrace) {
      final centrifugeException = CentrifugeSubscriptionException(
        message: 'Subscription is not subscribed',
        channel: channel,
        error: error,
      );
      _emitError(centrifugeException, stackTrace);
      Error.throwWithStackTrace(centrifugeException, stackTrace);
    }
  }

  /// Unsubscribe from a channel
  /// {@nodoc}
  @override
  Future<void> unsubscribe(
      [int code = 0, String reason = 'unsubscribe called']) async {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    if (state.isUnsubscribed) return;
    _setState(CentrifugeSubscriptionState.unsubscribed(
      code: code,
      reason: reason,
      since: since,
      recoverable: state.recoverable,
    ));
    if (!_transport.state.isConnected) return;
    try {
      await _transport.unsubscribe(channel, _config);
    } on Object catch (error, stackTrace) {
      final centrifugeException = CentrifugeSubscriptionException(
        message: 'Error while unsubscribing',
        channel: channel,
        error: error,
      );
      _emitError(centrifugeException, stackTrace);
      _transport
          .disconnect(
            DisconnectCode.unsubscribeError.code,
            DisconnectCode.unsubscribeError.reason,
          )
          .ignore();
      Error.throwWithStackTrace(centrifugeException, stackTrace);
    }
  }

  /// Refresh subscription when ttl is expired.
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
        logger.fine('Refreshing subscription token for $channel');
        try {
          _refreshTimer?.cancel();
          _refreshTimer = null;
          final token = await _config.getToken?.call();
          if (token == null || !state.isSubscribed) return;
          final result = await _transport.sendSubRefresh(channel, token);
          if (result.expires) _setRefreshTimer(result.ttl);
        } on Object catch (error, stackTrace) {
          logger.warning(
            error,
            stackTrace,
            'Error while refreshing subscription token',
          );
          _emitError(
            CentrifugeRefreshException(
              message: 'Error while refreshing subscription token',
              error: error,
            ),
            stackTrace,
          );
        }
      }).ignore();

  @override
  Future<void> close([int code = 0, String reason = 'closed']) async {
    logger.fine('Closing subscription to $channel');
    _refreshTimer?.cancel();
    _refreshTimer = null;
    try {
      if (!state.isUnsubscribed) await unsubscribe(code, reason);
    } on Object catch (error, stackTrace) {
      final centrifugeException = CentrifugeSubscriptionException(
        message: 'Error while unsubscribing from channel $channel',
        channel: channel,
        error: error,
      );
      _emitError(centrifugeException, stackTrace);
    }
    await super.close(code, reason);
  }
}

/// Mixin responsible for publishing.
/// {@nodoc}
@internal
base mixin CentrifugeClientSubscriptionPublishingMixin
    on
        CentrifugeClientSubscriptionBase,
        CentrifugeClientSubscriptionErrorsMixin {
  @override
  Future<void> publish(List<int> data) async {
    try {
      await ready();
      await _transport.publish(channel, data);
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

/// Mixin responsible for history.
/// {@nodoc}
@internal
base mixin CentrifugeClientSubscriptionHistoryMixin
    on
        CentrifugeClientSubscriptionBase,
        CentrifugeClientSubscriptionErrorsMixin {
  @override
  Future<CentrifugeHistory> history({
    int? limit,
    CentrifugeStreamPosition? since,
    bool? reverse,
  }) async {
    await ready();
    try {
      return await _transport.history(
        channel,
        limit: limit,
        since: since,
        reverse: reverse,
      );
    } on Object catch (error, stackTrace) {
      final centrifugeException = CentrifugeSubscriptionException(
        message: 'Error while fetching history',
        channel: channel,
        error: error,
      );
      _emitError(centrifugeException, stackTrace);
      Error.throwWithStackTrace(centrifugeException, stackTrace);
    }
  }
}

/// Mixin responsible for presence.
/// {@nodoc}
@internal
base mixin CentrifugeClientSubscriptionPresenceMixin
    on
        CentrifugeClientSubscriptionBase,
        CentrifugeClientSubscriptionErrorsMixin {
  @override
  Future<CentrifugePresence> presence() async {
    await ready();
    try {
      return await _transport.presence(channel);
    } on Object catch (error, stackTrace) {
      final centrifugeException = CentrifugeSubscriptionException(
        message: 'Error while fetching history',
        channel: channel,
        error: error,
      );
      _emitError(centrifugeException, stackTrace);
      Error.throwWithStackTrace(centrifugeException, stackTrace);
    }
  }

  @override
  Future<CentrifugePresenceStats> presenceStats() async {
    await ready();
    try {
      return await _transport.presenceStats(channel);
    } on Object catch (error, stackTrace) {
      final centrifugeException = CentrifugeSubscriptionException(
        message: 'Error while fetching history',
        channel: channel,
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
base mixin CentrifugeClientSubscriptionQueueMixin
    on CentrifugeClientSubscriptionBase {
  /// {@nodoc}
  final CentrifugeEventQueue _eventQueue = CentrifugeEventQueue();

  @override
  FutureOr<void> ready() => _eventQueue.push<void>(
        'ready',
        super.ready,
      );

  @override
  Future<void> subscribe() => _eventQueue.push<void>(
        'subscribe',
        super.subscribe,
      );

  @override
  Future<void> unsubscribe([
    int code = 0,
    String reason = 'unsubscribe called',
  ]) =>
      _eventQueue.push<void>(
        'unsubscribe',
        () => super.unsubscribe(code, reason),
      );

  @override
  Future<void> publish(List<int> data) => _eventQueue.push<void>(
        'publish',
        () => super.publish(data),
      );

  @override
  Future<CentrifugeHistory> history({
    int? limit,
    CentrifugeStreamPosition? since,
    bool? reverse,
  }) =>
      _eventQueue.push<CentrifugeHistory>(
        'history',
        () => super.history(
          limit: limit,
          since: since,
          reverse: reverse,
        ),
      );

  @override
  Future<CentrifugePresence> presence() =>
      _eventQueue.push<CentrifugePresence>('presence', super.presence);

  @override
  Future<CentrifugePresenceStats> presenceStats() => _eventQueue
      .push<CentrifugePresenceStats>('presenceStats', super.presenceStats);

  @override
  Future<void> close([int code = 0, String reason = 'closed']) => _eventQueue
      .push<void>('close', () => super.close(code, reason))
      .whenComplete(_eventQueue.close);
}
