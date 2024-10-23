import 'dart:async';

import 'model/annotations.dart';
import 'model/channel_event.dart';
import 'model/channel_events.dart';
import 'model/client_info.dart';
import 'model/command.dart';
import 'model/config.dart';
import 'model/constant.dart';
import 'model/exception.dart';
import 'model/history.dart';
import 'model/metric.dart';
import 'model/presence_stats.dart';
import 'model/reply.dart';
import 'model/state.dart';
import 'model/states_stream.dart';
import 'model/stream_position.dart';
import 'model/subscription_config.dart';
import 'spinify_interface.dart';
import 'subscription_interface.dart';

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
final class Spinify implements ISpinify {
  /// Create a new Spinify client.
  ///
  /// {@macro spinify}
  @safe
  Spinify({SpinifyConfig? config})
      : config = config ?? SpinifyConfig.byDefault() {
    /// Client initialization (from constructor).
    _log(
      const SpinifyLogLevel.info(),
      'init',
      'Spinify client initialized',
      <String, Object?>{
        'config': config,
      },
    );
  }

  /// Create client and connect.
  ///
  /// {@macro spinify}
  @safe
  factory Spinify.connect(String url, {SpinifyConfig? config}) =>
      Spinify(config: config)..connect(url).ignore();

  /// Spinify config.
  @safe
  @override
  final SpinifyConfig config;

  @safe
  @override
  SpinifyMetrics get metrics => _metrics.freeze();

  /// TODO: Transport implementation.
  dynamic _transport;

  /// Internal mutable metrics. Also it's container for Spinify's state.
  final SpinifyMetrics$Mutable _metrics = SpinifyMetrics$Mutable();

  @safe
  @override
  SpinifyState get state => _metrics.state;

  @safe
  @override
  bool get isClosed => _metrics.state.isClosed;

  @safe
  @override
  late final SpinifyStatesStream states =
      SpinifyStatesStream(_statesController.stream);

  @safe
  final StreamController<SpinifyState> _statesController =
      StreamController<SpinifyState>.broadcast();

  @override
  SpinifyChannelEvents<SpinifyChannelEvent> get stream =>
      throw UnimplementedError();

  /// Log an event with the given [level], [event], [message] and [context].
  @safe
  void _log(
    SpinifyLogLevel level,
    String event,
    String message,
    Map<String, Object?> context,
  ) {
    try {
      config.logger?.call(level, event, message, context);
    } on Object {/* ignore */}
  }

  /// Set a new state and notify listeners via [states].
  @safe
  void _setState(SpinifyState state) {
    if (isClosed) return;
    final previous = _metrics.state;
    _statesController.add(_metrics.state = state);
    _log(
      const SpinifyLogLevel.config(),
      'state_changed',
      'State changed from $previous to $state',
      <String, Object?>{
        'previous': previous,
        'state': state,
      },
    );
  }

  @unsafe
  @override
  @Throws([SpinifyConnectionException])
  Future<void> connect(String url) async {
    try {
      await _interactiveConnect(url);
    } on SpinifyConnectionException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        SpinifyConnectionException(
          message: 'Failed to connect to server',
          error: error,
        ),
        stackTrace,
      );
    }
  }

  /// User initiated connect.
  @unsafe
  Future<void> _interactiveConnect(String url) async {
    throw UnimplementedError();
  }

  /// Library initiated connect.
  @unsafe
  Future<void> _internalReconnect(String url) async {
    throw UnimplementedError();
  }

  /// On connect to the server.
  Future<void> _onConnected() async {}

  @safe
  @override
  Future<void> disconnect() => _interactiveDisconnect();

  /// User initiated disconnect.
  @safe
  Future<void> _interactiveDisconnect() =>
      _internalDisconnect(temporary: false);

  /// Library initiated disconnect.
  @safe
  Future<void> _internalDisconnect({required bool temporary}) async {
    try {
      // Close all pending replies with error.
      const error = SpinifyReplyException(
        replyCode: 0,
        replyMessage: 'Client is disconnected',
        temporary: true,
      );
      late final stackTrace = StackTrace.current;
      for (final completer in _replies.values) {
        if (completer.isCompleted) continue;
        completer.completeError(error, stackTrace);
        _log(
          const SpinifyLogLevel.warning(),
          'disconnected_reply_error',
          'Reply for command '
              '${completer.command.type}{id: ${completer.command.id}} '
              'error on disconnect',
          <String, Object?>{
            'command': completer.command,
            'error': error,
            'stackTrace': stackTrace,
          },
        );
      }
      _replies.clear();
    } on Object catch (error, stackTrace) {
      _log(
        const SpinifyLogLevel.warning(),
        'disconnected_error',
        'Error on disconnect',
        <String, Object?>{
          'error': error,
          'stackTrace': stackTrace,
        },
      );
    } finally {
      _setState(SpinifyState$Disconnected(temporary: temporary));
      _log(
        const SpinifyLogLevel.config(),
        'disconnected',
        'Disconnected from server',
        <String, Object?>{},
      );
    }
  }

  /// Plan to do action when client is connected.
  @unsafe
  Future<T> _doOnReady<T>(Future<T> Function() action) {
    if (state.isConnected) return action();
    return ready().then<T>((_) => action());
  }

  @safe
  @override
  Future<void> close() async {
    if (state.isClosed) return;
    try {
      _setState(SpinifyState$Closed());
      await _internalDisconnect(temporary: false);
    } on Object {/* ignore */} finally {
      _statesController.close().ignore();
      _log(
        const SpinifyLogLevel.info(),
        'closed',
        'Closed',
        <String, Object?>{
          'state': state,
        },
      );
    }
  }

  /// Counter for command messages.
  @safe
  int _getNextCommandId() {
    if (_metrics.commandId == kMaxInt) _metrics.commandId = 1;
    return _metrics.commandId++;
  }

  @override
  SpinifyClientSubscription? getClientSubscription(String channel) {
    throw UnimplementedError();
  }

  @override
  SpinifyServerSubscription? getServerSubscription(String channel) {
    throw UnimplementedError();
  }

  @override
  SpinifySubscription? getSubscription(String channel) {
    throw UnimplementedError();
  }

  @override
  Future<SpinifyHistory> history(
    String channel, {
    int? limit,
    SpinifyStreamPosition? since,
    bool? reverse,
  }) {
    throw UnimplementedError();
  }

  @override
  SpinifyClientSubscription newSubscription(
    String channel, {
    SpinifySubscriptionConfig? config,
    bool subscribe = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, SpinifyClientInfo>> presence(String channel) {
    throw UnimplementedError();
  }

  @override
  Future<SpinifyPresenceStats> presenceStats(String channel) {
    throw UnimplementedError();
  }

  @override
  Future<void> publish(String channel, List<int> data) {
    throw UnimplementedError();
  }

  @override
  Future<void> ready() {
    throw UnimplementedError();
  }

  @override
  Future<void> removeSubscription(SpinifyClientSubscription subscription) {
    throw UnimplementedError();
  }

  @override
  Future<List<int>> rpc(String method, [List<int>? data]) {
    throw UnimplementedError();
  }

  @unsafe
  Future<void> _sendCommandAsync(SpinifyCommand command) async {
    _log(
      const SpinifyLogLevel.debug(),
      'send_command_async_begin',
      'Comand ${command.type}{id: ${command.id}} sent async begin',
      <String, Object?>{
        'command': command,
      },
    );
    try {
      // coverage:ignore-start
      assert(command.id > -1, 'Command ID should be greater or equal to 0');
      assert(_transport != null, 'Transport is not connected');
      assert(!state.isClosed, 'State is closed');
      // coverage:ignore-end
      await _transport?.send(command);
      _log(
        const SpinifyLogLevel.config(),
        'send_command_async_success',
        'Command sent ${command.type}{id: ${command.id}} async successfully',
        <String, Object?>{
          'command': command,
        },
      );
    } on Object catch (error, stackTrace) {
      _log(
        const SpinifyLogLevel.warning(),
        'send_command_async_error',
        'Error sending command ${command.type}{id: ${command.id}} async',
        <String, Object?>{
          'command': command,
          'error': error,
          'stackTrace': stackTrace,
        },
      );
      rethrow;
    }
  }

  /// Hash map of pending replies.
  final Map<int, _PendingReply> _replies = <int, _PendingReply>{};

  /// Called when [SpinifyReply] received from the server.
  @safe
  @sideEffect
  Future<void> _onReply(SpinifyReply reply) async {
    try {
      // coverage:ignore-start
      if (reply.id < 0 || reply.id > _metrics.commandId) {
        assert(
            reply.id >= 0 && reply.id <= _metrics.commandId,
            'Reply ID should be greater or equal to 0 '
            'and less or equal than command ID');
        return;
      }
      // coverage:ignore-end
      if (reply.isResult) {
        // If reply is a result then find pending reply and complete it.
        if (reply.id case int id when id > 0) {
          final completer = _replies.remove(id);
          // coverage:ignore-start
          if (completer == null || completer.isCompleted) {
            assert(
              completer != null,
              'Reply completer not found',
            );
            assert(
              completer?.isCompleted == false,
              'Reply completer already completed',
            );
            return;
          }
          // coverage:ignore-end
          if (reply is SpinifyErrorResult) {
            completer.completeError(
              SpinifyReplyException(
                replyCode: reply.code,
                replyMessage: reply.message,
                temporary: reply.temporary,
              ),
              StackTrace.current,
            );
          } else {
            completer.complete(reply);
          }
        }
      }
      // ...
      _log(
        const SpinifyLogLevel.debug(),
        'reply',
        'Reply ${reply.type}{id: ${reply.id}} received',
        <String, Object?>{
          'reply': reply,
        },
      );
    } on Object catch (error, stackTrace) {
      _log(
        const SpinifyLogLevel.warning(),
        'reply_error',
        'Error processing reply',
        <String, Object?>{
          'reply': reply,
          'error': error,
          'stackTrace': stackTrace,
        },
      );
    }
  }

  @unsafe
  @override
  @Throws([SpinifySendException])
  Future<void> send(List<int> data) async {
    try {
      await _doOnReady(() => _sendCommandAsync(
            SpinifySendRequest(
              timestamp: DateTime.now(),
              data: data,
            ),
          ));
    } on SpinifySendException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(SpinifySendException(error: error), stackTrace);
    }
  }

  @override
  ({
    Map<String, SpinifyClientSubscription> client,
    Map<String, SpinifyServerSubscription> server
  }) get subscriptions => throw UnimplementedError();
}

/// Pending reply.
class _PendingReply {
  _PendingReply(this.command) : _completer = Completer<SpinifyReply>();

  final SpinifyCommand command;
  final Completer<SpinifyReply> _completer;

  bool get isCompleted => _completer.isCompleted;

  void complete(SpinifyReply reply) => _completer.complete(reply);

  void completeError(SpinifyReplyException error, StackTrace stackTrace) =>
      _completer.completeError(error, stackTrace);
}
