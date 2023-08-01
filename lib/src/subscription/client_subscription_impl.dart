import 'dart:async';

import 'package:centrifuge_dart/centrifuge.dart';
import 'package:centrifuge_dart/src/client/disconnect_code.dart';
import 'package:centrifuge_dart/src/model/channel_presence.dart';
import 'package:centrifuge_dart/src/model/channel_presence_stream.dart';
import 'package:centrifuge_dart/src/model/history.dart';
import 'package:centrifuge_dart/src/model/presence.dart';
import 'package:centrifuge_dart/src/model/presence_stats.dart';
import 'package:centrifuge_dart/src/model/stream_position.dart';
import 'package:centrifuge_dart/src/subscription/subscription_states_stream.dart';
import 'package:centrifuge_dart/src/transport/transport_interface.dart';
import 'package:centrifuge_dart/src/util/event_queue.dart';
import 'package:centrifuge_dart/src/util/logger.dart' as logger;
import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:meta/meta.dart';
import 'package:stack_trace/stack_trace.dart' as st;

/// Constroller responsible for managing subscription.
/// {@nodoc}
@internal
final class CentrifugeClientSubscriptionImpl
    extends CentrifugeClientSubscriptionBase
    with
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
    required WeakReference<ICentrifugeTransport> transportWeakRef,
    required CentrifugeSubscriptionConfig config,
  }) : _config = config {
    _transportWeakRef = transportWeakRef;
    _initSubscription();
  }

  @override
  final String channel;

  /// Offset of last received publication.
  late fixnum.Int64 _offset;

  /// Weak reference to transport.
  /// {@nodoc}
  @nonVirtual
  late final WeakReference<ICentrifugeTransport> _transportWeakRef;

  /// Internal transport responsible
  /// for sending, receiving, encoding and decoding data from the server.
  /// {@nodoc}
  ICentrifugeTransport get _transport => _transportWeakRef.target!;

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
    _stateController.add(_state = state);
  }

  /// Stream of publications.
  /// {@nodoc}
  @override
  Stream<CentrifugePublication> get publications =>
      _publicationController.stream;

  /// {@nodoc}
  final StreamController<CentrifugePublication> _publicationController =
      StreamController<CentrifugePublication>.broadcast();

  /// Notify about new publication.
  /// {@nodoc}
  @internal
  @nonVirtual
  void handlePublication(CentrifugePublication publication) {
    final offset = publication.offset;
    if (offset != null && offset > _offset) _offset = offset;
    _publicationController.add(publication);
  }

  /// {@nodoc}
  @internal
  @mustCallSuper
  Future<void> close() async {
    _publicationController.close().ignore();
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
      _setState(CentrifugeSubscriptionState$Subscribing(since: state.since));
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
        since: subscribed.since,
        recoverable: subscribed.recoverable,
        ttl: subscribed.ttl,
      ));
      if (subscribed.publications.isNotEmpty)
        subscribed.publications.forEach(handlePublication);
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
      since: state.since,
    ));
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
  Future<void> close() async {
    logger.fine('Closing subscription to $channel');
    _refreshTimer?.cancel();
    _refreshTimer = null;
    await super.close();
    await _transport.close();
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
  @protected
  @nonVirtual
  final StreamController<CentrifugeChannelPresenceEvent>
      _presenceEventsController =
      StreamController<CentrifugeChannelPresenceEvent>.broadcast();

  @override
  @nonVirtual
  late final CentrifugeChannelPresenceStream presenceEvents =
      CentrifugeChannelPresenceStream(_presenceEventsController.stream);

  /// Notify about new presence event.
  /// {@nodoc}
  @internal
  @nonVirtual
  void handlePresenceEvent(CentrifugeChannelPresenceEvent event) =>
      _presenceEventsController.add(event);

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
  Future<void> close() => _eventQueue
      .push<void>('close', super.close)
      .whenComplete(_eventQueue.close);
}
