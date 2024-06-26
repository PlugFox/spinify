import 'dart:async';

import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:meta/meta.dart';

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
import 'subscription_state.dart';
import 'subscription_states_stream.dart';

/// Server-side subscription implementation.
final class SpinifyServerSubscriptionImpl extends SpinifyServerSubscriptionBase
    with
        SpinifyServerSubscriptionEventReceiverMixin,
        SpinifyServerSubscriptionErrorsMixin,
        SpinifyServerSubscriptionReadyMixin,
        SpinifyServerSubscriptionPublishingMixin,
        SpinifyServerSubscriptionHistoryMixin,
        SpinifyServerSubscriptionPresenceMixin,
        SpinifyServerSubscriptionQueueMixin {
  /// Server-side subscription implementation.
  SpinifyServerSubscriptionImpl({
    required super.channel,
    required super.transportWeakRef,
  });
}

/// Base class for server-side subscription.
abstract base class SpinifyServerSubscriptionBase
    extends SpinifyServerSubscription {
  /// Base class for server-side subscription.
  SpinifyServerSubscriptionBase({
    required this.channel,
    required WeakReference<ISpinifyTransport> transportWeakRef,
  }) {
    _transportWeakRef = transportWeakRef;
    _initSubscription();
  }

  @override
  final String channel;

  @override
  SpinifyStreamPosition? get since => switch (state.since?.epoch) {
        String epoch => (epoch: epoch, offset: _offset),
        _ => state.since,
      };

  /// Offset of last received publication.
  fixnum.Int64 _offset = fixnum.Int64.ZERO;

  /// Weak reference to transport.
  @nonVirtual
  late final WeakReference<ISpinifyTransport> _transportWeakRef;

  /// Internal transport responsible
  /// for sending, receiving, encoding and decoding data from the server.
  ISpinifyTransport get _transport => _transportWeakRef.target!;

  /// Init subscription.
  @protected
  @mustCallSuper
  void _initSubscription() {
    _state =
        SpinifySubscriptionState.unsubscribed(code: 0, reason: 'initial state');
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
    if (!_state.isUnsubscribed)
      _setState(SpinifySubscriptionState.unsubscribed(
        code: 0,
        reason: 'closed',
        recoverable: false,
        since: since,
      ));
    _stateController.close().ignore();
  }

  @override
  String toString() => 'SpinifyServerSubscription{channel: $channel}';
}

/// Mixin responsible for event receiving and distribution by controllers
/// and streams to subscribers.
base mixin SpinifyServerSubscriptionEventReceiverMixin
    on SpinifyServerSubscriptionBase {
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
      case SpinifySubscribe sub:
        final offset = sub.streamPosition?.offset;
        if (offset != null && offset > _offset) _offset = offset;
        _setState(SpinifySubscriptionState.subscribed(
          since: sub.streamPosition ?? since,
          recoverable: sub.recoverable,
        ));
      case SpinifyUnsubscribe unsub:
        _setState(SpinifySubscriptionState.unsubscribed(
          code: unsub.code,
          reason: unsub.reason,
          recoverable: state.recoverable,
          since: since,
        ));
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
base mixin SpinifyServerSubscriptionErrorsMixin
    on SpinifyServerSubscriptionBase {
  @protected
  @nonVirtual
  void _emitError(SpinifyException exception, StackTrace stackTrace) =>
      Spinify.observer?.onError(exception, stackTrace);
}

/// Mixin responsible for ready method.
base mixin SpinifyServerSubscriptionReadyMixin
    on SpinifyServerSubscriptionBase, SpinifyServerSubscriptionErrorsMixin {
  /// Await for subscription to be ready.
  @override
  FutureOr<void> ready() async {
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
          await states.subscribed.first;
      }
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

  /// Mark subscription as ready.
  void setSubscribed() {
    if (!state.isSubscribed)
      _setState(SpinifySubscriptionState.subscribed(
        since: since,
        recoverable: state.recoverable,
      ));
  }

  /// Mark subscription as subscribing.
  void setSubscribing() {
    if (!state.isSubscribing)
      _setState(SpinifySubscriptionState.subscribing(
        since: since,
        recoverable: state.recoverable,
      ));
  }

  /// Mark subscription as unsubscribed.
  void setUnsubscribed(int code, String reason) {
    if (!state.isUnsubscribed)
      _setState(SpinifySubscriptionState.unsubscribed(
        code: code,
        reason: reason,
        recoverable: state.recoverable,
        since: since,
      ));
  }

  @override
  Future<void> close([int code = 0, String reason = 'closed']) async {
    logger.fine('Closing subscription to $channel');
    if (!state.isUnsubscribed) setUnsubscribed(code, reason);
    await super.close(code, reason);
  }
}

/// Mixin responsible for publishing.
base mixin SpinifyServerSubscriptionPublishingMixin
    on SpinifyServerSubscriptionBase, SpinifyServerSubscriptionErrorsMixin {
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
base mixin SpinifyServerSubscriptionHistoryMixin
    on SpinifyServerSubscriptionBase, SpinifyServerSubscriptionErrorsMixin {
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
base mixin SpinifyServerSubscriptionPresenceMixin
    on SpinifyServerSubscriptionBase, SpinifyServerSubscriptionErrorsMixin {
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
base mixin SpinifyServerSubscriptionQueueMixin
    on SpinifyServerSubscriptionBase {
  final SpinifyEventQueue _eventQueue = SpinifyEventQueue();

  @override
  FutureOr<void> ready() => _eventQueue.push<void>(
        'ready',
        super.ready,
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
