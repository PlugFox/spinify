import 'dart:async';

import 'package:centrifuge_dart/centrifuge.dart';
import 'package:centrifuge_dart/src/model/subscription_states_stream.dart';
import 'package:centrifuge_dart/src/transport/transport_interface.dart';
import 'package:centrifuge_dart/src/util/event_queue.dart';
import 'package:centrifuge_dart/src/util/logger.dart' as logger;
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
        CentrifugeClientSubscriptionQueueMixin {
  /// {@nodoc}
  CentrifugeClientSubscriptionImpl({
    required super.channel,
    required super.transportWeakRef,
    CentrifugeSubscriptionConfig? config,
  }) : super(config: config ?? const CentrifugeSubscriptionConfig.byDefault());

  /*
    publish(data) - publish data to Subscription channel
    history(options) - request Subscription channel history
    presence() - request Subscription channel online presence information
    presenceStats() - request Subscription channel online presence stats information (number of client connections and unique users in a channel).
  */
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
    // TODO(plugfox): subscribe on disconnections
  }

  /// Subscription has 3 states:
  /// - `unsubscribed`
  /// - `subscribing`
  /// - `subscribed`
  /// {@nodoc}
  @override
  CentrifugeSubscriptionState get state => _state;
  CentrifugeSubscriptionState _state =
      CentrifugeSubscriptionState.unsubscribed();

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

  /// Called when connection lost.
  /// Right before [CentrifugeState$Disconnected] state.
  /// {@nodoc}
  @protected
  @mustCallSuper
  void _onDisconnect() {
    logger.fine('Connection lost');
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

/// Mixin responsible for connection.
/// {@nodoc}
@internal
base mixin CentrifugeClientSubscriptionSubscribeMixin
    on
        CentrifugeClientSubscriptionBase,
        CentrifugeClientSubscriptionErrorsMixin {
  /// Start subscribing to a channel
  /// {@nodoc}
  @override
  Future<void> subscribe() async {
    logger.fine('Subscribing to $channel');
    try {
      if (state is CentrifugeSubscriptionState$Subscribed) return;
      if (state is CentrifugeSubscriptionState$Subscribing) {
        return await ready();
      }
      _setState(CentrifugeSubscriptionState$Subscribing());
      // TODO(plugfox): implement
    } on CentrifugeException catch (error, stackTrace) {
      _emitError(error, stackTrace);
      rethrow;
    } on Object catch (error, stackTrace) {
      final centrifugeException = CentrifugeSubscriptionException(
        message: 'Error while subscribing',
        subscription: this,
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
            subscription: this,
          );
        case CentrifugeSubscriptionState$Subscribed _:
          return;
        case CentrifugeSubscriptionState$Subscribing _:
          await states.subscribed.first.timeout(_config.timeout);
      }
    } on CentrifugeException catch (error, stackTrace) {
      _emitError(error, stackTrace);
      rethrow;
    } on Object catch (error, stackTrace) {
      final centrifugeException = CentrifugeSubscriptionException(
        message: 'Subscription is not subscribed',
        subscription: this,
        error: error,
      );
      _emitError(centrifugeException, stackTrace);
      Error.throwWithStackTrace(centrifugeException, stackTrace);
    }
  }

  /// Unsubscribe from a channel
  /// {@nodoc}
  @override
  Future<void> unsubscribe() async {
    // TODO(plugfox): implement
  }

  @override
  Future<void> close() async {
    logger.fine('Closing subscription to $channel');
    await super.close();
    await _transport.close();
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

  // TODO(plugfox): add all methods

  @override
  Future<void> close() => _eventQueue
      .push<void>('close', super.close)
      .whenComplete(_eventQueue.close);
}
