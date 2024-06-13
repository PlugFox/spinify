import 'dart:async';

import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:meta/meta.dart';

import '../client/disconnect_code.dart';
import '../client/spinify.dart';
import '../model/channel_presence.dart';
import '../model/channel_push.dart';
import '../model/connect.dart';
import '../model/disconnect.dart';
import '../model/event.dart';
import '../model/exception.dart';
import '../model/history.dart';
import '../model/message.dart';
import '../model/presence.dart';
import '../model/presence_stats.dart';
import '../model/publication.dart';
import '../model/pushes_stream.dart';
import '../model/refresh.dart';
import '../model/stream_position.dart';
import '../model/subscribe.dart';
import '../model/unsubscribe.dart';
import '../transport/transport_interface.dart';
import '../util/event_queue.dart';
import '../util/logger.dart' as logger;
import 'subscription.dart';
import 'subscription_config.dart';
import 'subscription_state.dart';
import 'subscription_states_stream.dart';

/// Client-side subscription implementation.
final class SpinifyClientSubscriptionImpl extends SpinifyClientSubscriptionBase
    with
        SpinifyClientSubscriptionEventReceiverMixin,
        SpinifyClientSubscriptionErrorsMixin,
        SpinifyClientSubscriptionSubscribeMixin,
        SpinifyClientSubscriptionPublishingMixin,
        SpinifyClientSubscriptionHistoryMixin,
        SpinifyClientSubscriptionPresenceMixin,
        SpinifyClientSubscriptionQueueMixin {
  /// Client-side subscription implementation.
  SpinifyClientSubscriptionImpl({
    required super.channel,
    required super.transportWeakRef,
    SpinifySubscriptionConfig? config,
  }) : super(config: config ?? const SpinifySubscriptionConfig.byDefault());
}

/// Base class for client-side subscription.
abstract base class SpinifyClientSubscriptionBase
    extends SpinifyClientSubscription {
  /// Client-side subscription implementation.
  SpinifyClientSubscriptionBase({
    required this.channel,
    required WeakReference<ISpinifyTransport> transportWeakRef,
    required SpinifySubscriptionConfig config,
  }) : _config = config {
    _transportWeakRef = transportWeakRef;
    _initSubscription();
  }

  @override
  final String channel;

  /// Offset of last received publication.
  late fixnum.Int64 _offset;

  @override
  SpinifyStreamPosition? get since => switch (state.since?.epoch) {
        String epoch => (epoch: epoch, offset: _offset),
        _ => state.since,
      };

  /// Weak reference to transport.
  @nonVirtual
  late final WeakReference<ISpinifyTransport> _transportWeakRef;

  /// Internal transport responsible
  /// for sending, receiving, encoding and decoding data from the server.
  ISpinifyTransport get _transport => _transportWeakRef.target!;

  /// Subscription config.
  final SpinifySubscriptionConfig _config;

  /// Init subscription.
  @protected
  @mustCallSuper
  void _initSubscription() {
    _state = SpinifySubscriptionState.unsubscribed(
        since: _config.since, code: 0, reason: 'initial state');
    _offset = _config.since?.offset ?? fixnum.Int64.ZERO;
  }

  /// Subscription has 3 states:
  /// - `unsubscribed`
  /// - `subscribing`
  /// - `subscribed`
  @override
  SpinifySubscriptionState get state => _state;
  late SpinifySubscriptionState _state;

  /// Stream of subscription states.
  @override
  late final SpinifySubscriptionStateStream states =
      SpinifySubscriptionStateStream(_stateController.stream);

  /// States controller.
  final StreamController<SpinifySubscriptionState> _stateController =
      StreamController<SpinifySubscriptionState>.broadcast();

  /// Set new state.
  void _setState(SpinifySubscriptionState state) {
    if (_state == state) return;
    final previousState = _state;
    _stateController.add(_state = state);
    Spinify.observer?.onSubscriptionChanged(this, previousState, state);
  }

  /// Notify about new publication.
  @nonVirtual
  void _handlePublication(SpinifyPublication publication) {
    final offset = publication.offset;
    if (offset != null && offset > _offset) _offset = offset;
  }

  /// Close subscription.
  @mustCallSuper
  Future<void> close([int code = 0, String reason = 'closed']) async {
    if (!_state.isUnsubscribed) {
      _setState(SpinifySubscriptionState.unsubscribed(
        code: code,
        reason: reason,
        recoverable: false,
        since: since,
      ));
    }
    _stateController.close().ignore();
  }

  @override
  String toString() => 'SpinifyClientSubscription{channel: $channel}';
}

/// Mixin responsible for event receiving and distribution by controllers
/// and streams to subscribers.
base mixin SpinifyClientSubscriptionEventReceiverMixin
    on SpinifyClientSubscriptionBase {
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
  void _initSubscription() {
    super._initSubscription();
  }

  /// Handle push event from server for the specific channel.
  /// Called from `SpinifyClientSubscriptionsManager.onPush`
  @nonVirtual
  void onPush(SpinifyChannelPush push) {
    // This is a push to a channel.
    _pushController.add(push);
    switch (push) {
      case SpinifyPublication publication:
        _handlePublication(publication);
        _publicationsController.add(publication);
      case SpinifyMessage message:
        _messagesController.add(message);
      case SpinifyJoin join:
        _presenceController.add(join);
        _joinController.add(join);
      case SpinifyLeave leave:
        _presenceController.add(leave);
        _leaveController.add(leave);
      case SpinifySubscribe _:
        break; // For server side subscriptions.
      case SpinifyUnsubscribe _:
        break; // For server side subscriptions.
      case SpinifyConnect _:
        break;
      case SpinifyDisconnect _:
        break;
      case SpinifyRefresh _:
        break;
    }
  }

  @override
  Future<void> close([int code = 0, String reason = 'closed']) async {
    await super.close(code, reason);
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

/// Mixin responsible for errors stream.
base mixin SpinifyClientSubscriptionErrorsMixin
    on SpinifyClientSubscriptionBase {
  @protected
  @nonVirtual
  void _emitError(SpinifyException exception, StackTrace stackTrace) =>
      Spinify.observer?.onError(exception, stackTrace);
}

/// Mixin responsible for subscribing.
base mixin SpinifyClientSubscriptionSubscribeMixin
    on SpinifyClientSubscriptionBase, SpinifyClientSubscriptionErrorsMixin {
  /// Refresh timer.
  Timer? _refreshTimer;

  /// Start subscribing to a channel
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
      _setState(SpinifySubscriptionState$Subscribing(
        since: since,
        recoverable: state.recoverable,
      ));
      final subscribed = await _transport.subscribe(
        channel,
        _config,
        switch (state.since) {
          null => null,
          (epoch: String epoch, offset: fixnum.Int64 _) => (
              epoch: epoch,
              offset: _offset,
            ),
        },
      );
      final offset = subscribed.since?.offset;
      if (offset != null && offset > _offset) _offset = offset;
      _setState(SpinifySubscriptionState$Subscribed(
        since: subscribed.since ?? since,
        recoverable: subscribed.recoverable,
        ttl: subscribed.ttl,
      ));
      if (subscribed.publications.isNotEmpty) {
        subscribed.publications.forEach(_handlePublication);
      }
      if (subscribed.expires) _setRefreshTimer(subscribed.ttl);
    } on SpinifyException catch (error, stackTrace) {
      unsubscribe(0, 'error while subscribing').ignore();
      _emitError(error, stackTrace);
      rethrow;
    } on Object catch (error, stackTrace) {
      unsubscribe(0, 'error while subscribing').ignore();
      final spinifyException = SpinifySubscriptionException(
        message: 'Error while subscribing',
        channel: channel,
        error: error,
      );
      _emitError(spinifyException, stackTrace);
      Error.throwWithStackTrace(spinifyException, stackTrace);
    }
  }

  /// Await for subscription to be ready.
  @override
  Future<void> ready() async {
    try {
      switch (state) {
        case SpinifySubscriptionState$Unsubscribed _:
          throw SpinifySubscriptionException(
            message: 'Subscription is not subscribed',
            channel: channel,
          );
        case SpinifySubscriptionState$Subscribed _:
          return;
        case SpinifySubscriptionState$Subscribing _:
          await states.subscribed.first.timeout(_config.timeout);
      }
    } on TimeoutException catch (error, stackTrace) {
      _transport
          .disconnect(
            DisconnectCode.timeout.code,
            DisconnectCode.timeout.reason,
          )
          .ignore();
      final spinifyException = SpinifySubscriptionException(
        message: 'Timeout exception while waiting for subscribing to $channel',
        channel: channel,
        error: error,
      );
      _emitError(spinifyException, stackTrace);
      Error.throwWithStackTrace(spinifyException, stackTrace);
    } on SpinifyException catch (error, stackTrace) {
      _emitError(error, stackTrace);
      rethrow;
    } on Object catch (error, stackTrace) {
      final spinifyException = SpinifySubscriptionException(
        message: 'Subscription is not subscribed',
        channel: channel,
        error: error,
      );
      _emitError(spinifyException, stackTrace);
      Error.throwWithStackTrace(spinifyException, stackTrace);
    }
  }

  /// Unsubscribe from a channel
  @override
  Future<void> unsubscribe(
      [int code = 0, String reason = 'unsubscribe called']) async {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    if (state.isUnsubscribed) return;
    _setState(SpinifySubscriptionState.unsubscribed(
      code: code,
      reason: reason,
      since: since,
      recoverable: state.recoverable,
    ));
    if (!_transport.state.isConnected) return;
    try {
      await _transport.unsubscribe(channel, _config);
    } on Object catch (error, stackTrace) {
      final spinifyException = SpinifySubscriptionException(
        message: 'Error while unsubscribing',
        channel: channel,
        error: error,
      );
      _emitError(spinifyException, stackTrace);
      _transport
          .disconnect(
            DisconnectCode.unsubscribeError.code,
            DisconnectCode.unsubscribeError.reason,
          )
          .ignore();
      Error.throwWithStackTrace(spinifyException, stackTrace);
    }
  }

  /// Refresh subscription when ttl is expired.
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
            SpinifyRefreshException(
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
      final spinifyException = SpinifySubscriptionException(
        message: 'Error while unsubscribing from channel $channel',
        channel: channel,
        error: error,
      );
      _emitError(spinifyException, stackTrace);
    }
    await super.close(code, reason);
  }
}

/// Mixin responsible for publishing.
base mixin SpinifyClientSubscriptionPublishingMixin
    on SpinifyClientSubscriptionBase, SpinifyClientSubscriptionErrorsMixin {
  @override
  Future<void> publish(List<int> data) async {
    try {
      await ready();
      await _transport.publish(channel, data);
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

/// Mixin responsible for history.
base mixin SpinifyClientSubscriptionHistoryMixin
    on SpinifyClientSubscriptionBase, SpinifyClientSubscriptionErrorsMixin {
  @override
  Future<SpinifyHistory> history({
    int? limit,
    SpinifyStreamPosition? since,
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
      final spinifyException = SpinifySubscriptionException(
        message: 'Error while fetching history',
        channel: channel,
        error: error,
      );
      _emitError(spinifyException, stackTrace);
      Error.throwWithStackTrace(spinifyException, stackTrace);
    }
  }
}

/// Mixin responsible for presence.
base mixin SpinifyClientSubscriptionPresenceMixin
    on SpinifyClientSubscriptionBase, SpinifyClientSubscriptionErrorsMixin {
  @override
  Future<SpinifyPresence> presence() async {
    await ready();
    try {
      return await _transport.presence(channel);
    } on Object catch (error, stackTrace) {
      final spinifyException = SpinifySubscriptionException(
        message: 'Error while fetching history',
        channel: channel,
        error: error,
      );
      _emitError(spinifyException, stackTrace);
      Error.throwWithStackTrace(spinifyException, stackTrace);
    }
  }

  @override
  Future<SpinifyPresenceStats> presenceStats() async {
    await ready();
    try {
      return await _transport.presenceStats(channel);
    } on Object catch (error, stackTrace) {
      final spinifyException = SpinifySubscriptionException(
        message: 'Error while fetching history',
        channel: channel,
        error: error,
      );
      _emitError(spinifyException, stackTrace);
      Error.throwWithStackTrace(spinifyException, stackTrace);
    }
  }
}

/// Mixin responsible for queue.
/// SHOULD BE LAST MIXIN.
base mixin SpinifyClientSubscriptionQueueMixin
    on SpinifyClientSubscriptionBase {
  final SpinifyEventQueue _eventQueue = SpinifyEventQueue();

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
  Future<SpinifyHistory> history({
    int? limit,
    SpinifyStreamPosition? since,
    bool? reverse,
  }) =>
      _eventQueue.push<SpinifyHistory>(
        'history',
        () => super.history(
          limit: limit,
          since: since,
          reverse: reverse,
        ),
      );

  @override
  Future<SpinifyPresence> presence() =>
      _eventQueue.push<SpinifyPresence>('presence', super.presence);

  @override
  Future<SpinifyPresenceStats> presenceStats() => _eventQueue
      .push<SpinifyPresenceStats>('presenceStats', super.presenceStats);

  @override
  Future<void> close([int code = 0, String reason = 'closed']) => _eventQueue
      .push<void>('close', () => super.close(code, reason))
      .whenComplete(_eventQueue.close);
}
