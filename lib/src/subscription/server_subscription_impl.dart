import 'dart:async';

import 'package:centrifuge_dart/src/model/channel_presence.dart';
import 'package:centrifuge_dart/src/model/channel_push.dart';
import 'package:centrifuge_dart/src/model/connect.dart';
import 'package:centrifuge_dart/src/model/disconnect.dart';
import 'package:centrifuge_dart/src/model/event.dart';
import 'package:centrifuge_dart/src/model/exception.dart';
import 'package:centrifuge_dart/src/model/history.dart';
import 'package:centrifuge_dart/src/model/message.dart';
import 'package:centrifuge_dart/src/model/presence.dart';
import 'package:centrifuge_dart/src/model/presence_stats.dart';
import 'package:centrifuge_dart/src/model/publication.dart';
import 'package:centrifuge_dart/src/model/pushes_stream.dart';
import 'package:centrifuge_dart/src/model/refresh.dart';
import 'package:centrifuge_dart/src/model/stream_position.dart';
import 'package:centrifuge_dart/src/model/subscribe.dart';
import 'package:centrifuge_dart/src/model/unsubscribe.dart';
import 'package:centrifuge_dart/src/subscription/subscription.dart';
import 'package:centrifuge_dart/src/subscription/subscription_state.dart';
import 'package:centrifuge_dart/src/subscription/subscription_states_stream.dart';
import 'package:centrifuge_dart/src/transport/transport_interface.dart';
import 'package:centrifuge_dart/src/util/event_queue.dart';
import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:meta/meta.dart';
import 'package:stack_trace/stack_trace.dart' as st;

/// Server-side subscription implementation.
/// {@nodoc}
@internal
final class CentrifugeServerSubscriptionImpl
    extends CentrifugeServerSubscriptionBase
    with
        CentrifugeServerSubscriptionEventReceiverMixin,
        CentrifugeServerSubscriptionErrorsMixin,
        CentrifugeServerSubscriptionReadyMixin,
        CentrifugeServerSubscriptionPublishingMixin,
        CentrifugeServerSubscriptionHistoryMixin,
        CentrifugeServerSubscriptionPresenceMixin,
        CentrifugeServerSubscriptionQueueMixin {
  /// {@nodoc}
  CentrifugeServerSubscriptionImpl({
    required super.channel,
    required super.transportWeakRef,
  });
}

/// {@nodoc}
@internal
abstract base class CentrifugeServerSubscriptionBase
    implements CentrifugeServerSubscription {
  /// {@nodoc}
  CentrifugeServerSubscriptionBase({
    required this.channel,
    required WeakReference<ICentrifugeTransport> transportWeakRef,
  }) {
    _transportWeakRef = transportWeakRef;
    _initSubscription();
  }

  @override
  final String channel;

  @override
  CentrifugeStreamPosition? get since => switch (state.since?.epoch) {
        String epoch => (epoch: epoch, offset: _offset),
        _ => null,
      };

  /// Offset of last received publication.
  fixnum.Int64 _offset = fixnum.Int64.ZERO;

  /// Weak reference to transport.
  /// {@nodoc}
  @nonVirtual
  late final WeakReference<ICentrifugeTransport> _transportWeakRef;

  /// Internal transport responsible
  /// for sending, receiving, encoding and decoding data from the server.
  /// {@nodoc}
  ICentrifugeTransport get _transport => _transportWeakRef.target!;

  /// Init subscription.
  /// {@nodoc}
  @protected
  @mustCallSuper
  void _initSubscription() {
    _state = CentrifugeSubscriptionState.unsubscribed(
        code: 0, reason: 'initial state');
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
  Future<void> close() async {
    _stateController.close().ignore();
  }
}

/// Mixin responsible for event receiving and distribution by controllers
/// and streams to subscribers.
/// {@nodoc}
base mixin CentrifugeServerSubscriptionEventReceiverMixin
    on CentrifugeServerSubscriptionBase {
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
      case CentrifugeSubscribe sub:
        final offset = sub.streamPosition?.offset;
        if (offset != null && offset > _offset) _offset = offset;
        _setState(CentrifugeSubscriptionState.subscribed(
          since: sub.streamPosition ?? since ?? state.since,
          recoverable: sub.recoverable,
        ));
      case CentrifugeUnsubscribe unsub:
        _setState(CentrifugeSubscriptionState.unsubscribed(
          code: unsub.code,
          reason: unsub.reason,
          recoverable: state.recoverable,
          since: since ?? state.since,
        ));
      case CentrifugeConnect _:
        break;
      case CentrifugeDisconnect _:
        break;
      case CentrifugeRefresh _:
        break;
    }
  }

  @override
  Future<void> close() async {
    await super.close();
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
base mixin CentrifugeServerSubscriptionErrorsMixin
    on CentrifugeServerSubscriptionBase {
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

/// Mixin responsible for ready method.
/// {@nodoc}
@internal
base mixin CentrifugeServerSubscriptionReadyMixin
    on
        CentrifugeServerSubscriptionBase,
        CentrifugeServerSubscriptionErrorsMixin {
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
          await states.subscribed.first;
      }
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
}

/// Mixin responsible for publishing.
/// {@nodoc}
@internal
base mixin CentrifugeServerSubscriptionPublishingMixin
    on
        CentrifugeServerSubscriptionBase,
        CentrifugeServerSubscriptionErrorsMixin {
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
base mixin CentrifugeServerSubscriptionHistoryMixin
    on
        CentrifugeServerSubscriptionBase,
        CentrifugeServerSubscriptionErrorsMixin {
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
base mixin CentrifugeServerSubscriptionPresenceMixin
    on
        CentrifugeServerSubscriptionBase,
        CentrifugeServerSubscriptionErrorsMixin {
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
base mixin CentrifugeServerSubscriptionQueueMixin
    on CentrifugeServerSubscriptionBase {
  /// {@nodoc}
  final CentrifugeEventQueue _eventQueue = CentrifugeEventQueue();

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
