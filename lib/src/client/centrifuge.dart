import 'dart:async';

import 'package:centrifuge_dart/src/client/centrifuge_interface.dart';
import 'package:centrifuge_dart/src/model/config.dart';
import 'package:centrifuge_dart/src/model/exception.dart';
import 'package:centrifuge_dart/src/model/state.dart';
import 'package:centrifuge_dart/src/model/states_stream.dart';
import 'package:centrifuge_dart/src/model/subscription.dart';
import 'package:centrifuge_dart/src/model/subscription_config.dart';
import 'package:centrifuge_dart/src/subscription/client_subscription_manager.dart';
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
        CentrifugeErrorsMixin,
        CentrifugeConnectionMixin,
        CentrifugeSendMixin,
        CentrifugeClientSubscriptionMixin,
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
    _transport = CentrifugeWebSocketProtobufTransport(
      config: config,
      disconnectCallback: _onDisconnect,
    );
    _initCentrifuge();
  }

  /// Internal transport responsible
  /// for sending, receiving, encoding and decoding data from the server.
  /// {@nodoc}
  @nonVirtual
  late final ICentrifugeTransport _transport;

  @override
  @nonVirtual
  CentrifugeState get state => _transport.state;

  @override
  late final CentrifugeStatesStream states =
      CentrifugeStatesStream(_transport.states);

  /// Centrifuge config.
  /// {@nodoc}
  @nonVirtual
  final CentrifugeConfig _config;

  /// Init centrifuge client, override this method to add custom logic.
  /// This method is called in constructor.
  /// {@nodoc}
  @protected
  @mustCallSuper
  void _initCentrifuge() {}

  /// Called when connection lost.
  /// Right before [CentrifugeState$Disconnected] state.
  /// {@nodoc}
  @protected
  @mustCallSuper
  void _onDisconnect() {
    logger.fine('Connection lost');
  }

  @override
  @mustCallSuper
  Future<void> close() async {}
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
base mixin CentrifugeConnectionMixin on CentrifugeBase, CentrifugeErrorsMixin {
  @override
  Future<void> connect(String url) async {
    logger.fine('Interactively connecting to $url');
    try {
      await _transport.connect(url);
    } on CentrifugeException catch (error, stackTrace) {
      _emitError(error, stackTrace);
      rethrow;
    } on Object catch (error, stackTrace) {
      final centrifugeException = CentrifugeConnectionException(error);
      _emitError(centrifugeException, stackTrace);
      Error.throwWithStackTrace(centrifugeException, stackTrace);
    }
  }

  @override
  FutureOr<void> ready() async {
    try {
      switch (state) {
        case CentrifugeState$Disconnected _:
          throw const CentrifugeDisconnectionException(
            message: 'Client is not connected',
          );
        case CentrifugeState$Closed _:
          throw const CentrifugeDisconnectionException(
            message: 'Client is permanently closed',
          );
        case CentrifugeState$Connected _:
          return;
        case CentrifugeState$Connecting _:
          await states.connected.first.timeout(_config.timeout);
      }
    } on CentrifugeException catch (error, stackTrace) {
      _emitError(error, stackTrace);
      rethrow;
    } on Object catch (error, stackTrace) {
      final centrifugeException = CentrifugeDisconnectionException(
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
      final centrifugeException = CentrifugeConnectionException(error);
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
    } on CentrifugeException {
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
  late final ClientSubscriptionManager _clientSubscriptionManager =
      ClientSubscriptionManager(_transport);

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
        subscription: subscription,
        message: 'Error while unsubscribing',
        error: error,
      );
      _emitError(centrifugeException, stackTrace);
      Error.throwWithStackTrace(centrifugeException, stackTrace);
    }
  }

  @override
  void _onDisconnect() {
    super._onDisconnect();
    _clientSubscriptionManager.disconnectAll();
  }

  @override
  Future<void> close() async {
    await super.close();
    _clientSubscriptionManager.removeAll();
  }
}

/// Mixin responsible for queue.
/// SHOULD BE LAST MIXIN.
/// {@nodoc}
@internal
base mixin CentrifugeQueueMixin on CentrifugeBase {
  /// {@nodoc}
  final CentrifugeEventQueue _eventQueue = CentrifugeEventQueue();

  // TODO(plugfox): add all methods

  @override
  Future<void> connect(String url) =>
      _eventQueue.push<void>('connect', () => super.connect(url));

  @override
  FutureOr<void> ready() => _eventQueue.push<void>('ready', super.ready);

  @override
  Future<void> disconnect() =>
      _eventQueue.push<void>('disconnect', super.disconnect);

  @override
  Future<void> close() => _eventQueue
      .push<void>('close', super.close)
      .whenComplete(_eventQueue.close);
}
