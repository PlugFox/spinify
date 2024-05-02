import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:protobuf/protobuf.dart' as pb;
import 'package:spinify/src/client/config.dart';
import 'package:spinify/src/client/disconnect_code.dart';
import 'package:spinify/src/client/state.dart';
import 'package:spinify/src/model/channel_presence.dart';
import 'package:spinify/src/model/client_info.dart';
import 'package:spinify/src/model/connect.dart';
import 'package:spinify/src/model/disconnect.dart';
import 'package:spinify/src/model/event.dart';
import 'package:spinify/src/model/exception.dart';
import 'package:spinify/src/model/history.dart';
import 'package:spinify/src/model/message.dart';
import 'package:spinify/src/model/presence.dart';
import 'package:spinify/src/model/presence_stats.dart';
import 'package:spinify/src/model/publication.dart';
import 'package:spinify/src/model/refresh.dart';
import 'package:spinify/src/model/refresh_result.dart';
import 'package:spinify/src/model/stream_position.dart';
import 'package:spinify/src/model/subscribe.dart';
import 'package:spinify/src/model/unsubscribe.dart';
import 'package:spinify/src/subscription/server_subscription_manager.dart';
import 'package:spinify/src/subscription/subcibed_on_channel.dart';
import 'package:spinify/src/subscription/subscription.dart';
import 'package:spinify/src/subscription/subscription_config.dart';
import 'package:spinify/src/subscription/subscription_state.dart';
import 'package:spinify/src/transport/protobuf/client.pb.dart' as pb;
import 'package:spinify/src/transport/transport_interface.dart';
import 'package:spinify/src/transport/transport_protobuf_codec.dart';
import 'package:spinify/src/util/logger.dart' as logger;
import 'package:spinify/src/util/notifier.dart';
import 'package:spinify/src/util/speed_meter.dart';
import 'package:ws/ws.dart';

@internal
abstract base class SpinifyWSPBTransportBase implements ISpinifyTransport {
  SpinifyWSPBTransportBase({
    required SpinifyConfig config,
  })  : _config = config,
        _webSocket = WebSocketClient(
          WebSocketOptions.selector(
            js: () => WebSocketOptions.js(
              connectionRetryInterval: null,
              protocols: _$protocolsSpinifyProtobuf,
              timeout: config.timeout,
              useBlobForBinary: false,
            ),
            vm: () => WebSocketOptions.vm(
              connectionRetryInterval: null,
              protocols: _$protocolsSpinifyProtobuf,
              timeout: config.timeout,
              headers: config.headers,
            ),
          ),
        ) {
    _initTransport();
  }

  /// Protocols for websocket.
  static const List<String> _$protocolsSpinifyProtobuf = <String>[
    'centrifuge-protobuf'
  ];

  /// Spinify config.
  final SpinifyConfig _config;

  @override
  final SpinifyChangeNotifier<SpinifyEvent> events =
      SpinifyChangeNotifier<SpinifyEvent>();

  /// Init transport, override this method to add custom logic.
  @protected
  @mustCallSuper
  void _initTransport() {}

  /// Websocket client.
  @nonVirtual
  final WebSocketClient _webSocket;

  @override
  @mustCallSuper
  Future<void> connect(
    String url,
    ServerSubscriptionManager serverSubscriptionManager,
  ) async {}

  @override
  @mustCallSuper
  Future<void> disconnect(int code, String reason) async {
    if (_webSocket.state.readyState.isDisconnecting ||
        _webSocket.state.readyState.isClosed) {
      // Already disconnected - do nothing.
      return;
    }
    await _webSocket.disconnect(code, reason);
  }

  @override
  @mustCallSuper
  Future<void> close() async {
    await disconnect(DisconnectCode.disconnectCalled.code, 'Client closed');
    await _webSocket.close();
    events.close();
  }
}

/// Class responsible for sending and receiving data from the server
/// through the Protobuf & WebSocket protocol.
@internal
// ignore: lines_longer_than_80_chars
final class SpinifyWSPBTransport = SpinifyWSPBTransportBase
    with
        SpinifyWSPBReplyMixin,
        SpinifyWSPBStateHandlerMixin,
        SpinifyWSPBSenderMixin,
        SpinifyWSPBConnectionMixin,
        SpinifyWSPBPingPongMixin,
        SpinifyWSPBSubscription,
        SpinifyWSPBHandlerMixin;

/// Stored completer for responses.
typedef _ReplyCompleter = ({
  void Function(pb.Reply reply) complete,
  void Function(Object error, StackTrace stackTrace) fail,
});

/// Mixin responsible for holding reply completers.
@internal
base mixin SpinifyWSPBReplyMixin on SpinifyWSPBTransportBase {
  /// Completers for messages by id.
  /// Contains timer for timeout and completer for response.
  final Map<int, _ReplyCompleter> _replyCompleters = <int, _ReplyCompleter>{};

  /// Observe reply future by command id.
  Future<pb.Reply> _awaitReply(int commandId, [Duration? timeout]) {
    final completer = Completer<pb.Reply>.sync();
    final timeoutTimer = timeout != null && timeout > Duration.zero
        ? Timer(
            _config.timeout,
            () => _replyCompleters.remove(commandId)?.fail(
                  TimeoutException('Timeout for command #$commandId'),
                  StackTrace.current,
                ),
          )
        : null;
    // Add completer to Hash Table for future response.
    // Completer will be completed by [_handleWebSocketMessage].
    _replyCompleters[commandId] = (
      complete: (reply) {
        timeoutTimer?.cancel();
        _replyCompleters.remove(commandId);
        if (completer.isCompleted) return;
        completer.complete(reply);
      },
      fail: (error, stackTrace) {
        logger.warning(
          error,
          StackTrace.current,
          'Error while processing reply',
        );
        timeoutTimer?.cancel();
        _replyCompleters.remove(commandId);
        if (completer.isCompleted) return;
        completer.completeError(error, stackTrace);
      },
    );
    return completer.future;
  }

  /// Complete reply by id.
  void _completeReply(pb.Reply reply) =>
      _replyCompleters.remove(reply.id)?.complete(reply);

  /// Fail all replies.
  void _failAllReplies(Object error, StackTrace stackTrace) {
    for (final completer in _replyCompleters.values) {
      completer.fail(error, stackTrace);
    }
    _replyCompleters.clear();
  }
}

/// Mixin responsible for sending data through websocket with protobuf.
@internal
base mixin SpinifyWSPBSenderMixin
    on SpinifyWSPBTransportBase, SpinifyWSPBReplyMixin {
  /// Encoder protobuf commands to bytes.
  static const Converter<pb.Command, List<int>> _commandEncoder =
      TransportProtobufEncoder();

  /// Speed meter of the connection.
  final SpinifySpeedMeter _speedMeter = SpinifySpeedMeter(15);

  @override
  ({int min, int avg, int max}) get speed => _speedMeter.speed;

  /// Counter for messages.
  int _messageId = 1;

  @nonVirtual
  @protected
  Future<Rep> _sendMessage<Req extends pb.GeneratedMessage,
      Rep extends pb.GeneratedMessage>(
    Req request,
    Rep result,
  ) async {
    final command = _createCommand(request, false);
    // Send command and wait for response.
    final future = _awaitReply(command.id);
    final stopwatch = Stopwatch()..start();
    pb.Reply reply;
    try {
      await _sendCommand(command);
      reply = await future;
      _speedMeter.add(stopwatch.elapsedMilliseconds);
    } finally {
      stopwatch.stop();
    }
    if (reply.hasError()) {
      throw SpinifyReplyException(
        replyCode: reply.error.code,
        replyMessage: reply.error.message,
        temporary: reply.error.temporary,
      );
    }
    if (reply.hasConnect()) {
      return result..mergeFromMessage(reply.connect);
    } else if (reply.hasSubscribe()) {
      return result..mergeFromMessage(reply.subscribe);
    } else if (reply.hasPublish()) {
      return result..mergeFromMessage(reply.publish);
    } else if (reply.hasPing()) {
      return result..mergeFromMessage(reply.publish);
    } else if (reply.hasUnsubscribe()) {
      return result..mergeFromMessage(reply.unsubscribe);
    } else if (reply.hasPresence()) {
      return result..mergeFromMessage(reply.presence);
    } else if (reply.hasPresenceStats()) {
      return result..mergeFromMessage(reply.presenceStats);
    } else if (reply.hasHistory()) {
      return result..mergeFromMessage(reply.history);
    } else if (reply.hasRpc()) {
      return result..mergeFromMessage(reply.rpc);
    } else if (reply.hasRefresh()) {
      return result..mergeFromMessage(reply.refresh);
    } else if (reply.hasSubRefresh()) {
      return result..mergeFromMessage(reply.subRefresh);
    } else {
      throw ArgumentError('Unknown reply type: $reply}');
    }
  }

  @override
  Future<void> sendAsyncMessage(List<int> data) =>
      _sendAsyncMessage(pb.Message()..data = data);

  @nonVirtual
  @protected
  Future<void> _sendAsyncMessage<Req extends pb.GeneratedMessage>(
    Req request,
  ) async {
    final command = _createCommand(request, true);
    return _sendCommand(command);
  }

  pb.Command _createCommand(
    pb.GeneratedMessage request,
    bool isAsync,
  ) {
    late final cmd = pb.Command();
    switch (request) {
      case pb.ConnectRequest request:
        cmd.connect = request;
      case pb.PublishRequest request:
        cmd.publish = request;
      case pb.PingRequest request:
        cmd.ping = request;
      case pb.SubscribeRequest request:
        cmd.subscribe = request;
      case pb.UnsubscribeRequest request:
        cmd.unsubscribe = request;
      case pb.HistoryRequest request:
        cmd.history = request;
      case pb.PresenceRequest request:
        cmd.presence = request;
      case pb.PresenceStatsRequest request:
        cmd.presenceStats = request;
      case pb.RPCRequest request:
        cmd.rpc = request;
      case pb.RefreshRequest request:
        cmd.refresh = request;
      case pb.SubRefreshRequest request:
        cmd.subRefresh = request;
      case pb.SendRequest request:
        cmd.send = request;
      case pb.Command _:
        // Already a command, do nothing and return it.
        // e.g. used for pong async message.
        return request;
      default:
        throw ArgumentError('unknown request type');
    }
    if (!isAsync) cmd.id = _messageId++;
    return cmd;
  }

  BigInt _transferredCount = BigInt.zero;
  BigInt _transferredSize = BigInt.zero;
  @override
  ({BigInt count, BigInt size}) get transferred =>
      (count: _transferredCount, size: _transferredSize);

  Future<void> _sendCommand(pb.Command command) async {
    if (!_webSocket.state.readyState.isOpen) throw StateError('Not connected');
    final data = _commandEncoder.convert(command);
    await _webSocket.add(data);
    _transferredCount += BigInt.one;
    _transferredSize += BigInt.from(data.length);
  }
}

/// Mixin responsible for connection.
@internal
base mixin SpinifyWSPBConnectionMixin
    on
        SpinifyWSPBTransportBase,
        SpinifyWSPBSenderMixin,
        SpinifyWSPBStateHandlerMixin {
  @override
  Future<void> connect(
    String url,
    ServerSubscriptionManager serverSubscriptionManager,
  ) async {
    try {
      await super.connect(url, serverSubscriptionManager);
      await _webSocket.connect(url);
      final request = pb.ConnectRequest();
      final token = await _config.getToken?.call();
      assert(token == null || token.length > 5, 'Spinify JWT is too short');
      if (token != null) request.token = token;
      final payload = await _config.getPayload?.call();
      if (payload != null) request.data = payload;
      request
        ..name = _config.client.name
        ..version = _config.client.version;
      // Add server-side subscriptions to connect request.
      {
        final subs = serverSubscriptionManager.subscriptions.values;
        for (final SpinifyServerSubscription(
              channel: String channel,
              state: SpinifySubscriptionState(:recoverable, :since),
            ) in subs) {
          if (since == null) continue;
          final subRequest = pb.SubscribeRequest()
            ..recover = recoverable
            ..offset = since.offset
            ..epoch = since.epoch;
          request.subs.putIfAbsent(channel, () => subRequest);
        }
      }
      final pb.ConnectResult result;
      try {
        result = await _sendMessage(request, pb.ConnectResult());
      } on Object catch (error, stackTrace) {
        Error.throwWithStackTrace(
          SpinifyConnectionException(
            message: 'Error while making connect request',
            error: error,
          ),
          stackTrace,
        );
      }
      if (!_webSocket.state.readyState.isOpen) {
        throw StateError('Connection closed during connection process');
      }
      final now = DateTime.now();
      final expires = result.hasExpires() && result.expires && result.hasTtl();

      // Update server-side subscriptions.
      {
        final subs = result.subs.entries.map<SpinifySubscribe>((e) {
          final channel = e.key;
          final sub = e.value;
          final positioned = sub.hasPositioned() && sub.positioned;
          final recoverable = sub.hasRecoverable() && sub.recoverable;
          return SpinifySubscribe(
            timestamp: now,
            channel: channel,
            positioned: positioned,
            recoverable: recoverable,
            data: sub.hasData() ? sub.data : const <int>[],
            streamPosition:
                (positioned || recoverable) && sub.hasOffset() && sub.hasEpoch()
                    ? (offset: sub.offset, epoch: sub.epoch)
                    : null,
          );
        }).toList(growable: false);
        serverSubscriptionManager.upsert(subs);
      }

      _setState(SpinifyState$Connected(
        url: url,
        timestamp: now,
        client: result.hasClient() ? result.client : null,
        version: result.hasVersion() ? result.version : null,
        expires: expires,
        ttl: expires ? now.add(Duration(seconds: result.ttl)) : null,
        node: result.hasNode() ? result.node : null,
        pingInterval: result.hasPing() ? Duration(seconds: result.ping) : null,
        sendPong: result.hasPong() ? result.pong : null,
        session: result.hasSession() ? result.session : null,
        data: result.hasData() ? result.data : null,
      ));
    } on Object {
      disconnect(DisconnectCode.unauthorized.code, 'Connection failed')
          .ignore();
      rethrow;
    }
  }

  @override
  Future<SpinifyRefreshResult> sendRefresh(String token) {
    if (!_state.isConnected) throw StateError('Not connected');
    return _sendMessage(pb.RefreshRequest()..token = token, pb.RefreshResult())
        .then<SpinifyRefreshResult>(
      (result) {
        final state = _state;
        if (state is SpinifyState$Connected) {
          final now = DateTime.now();
          final expires =
              result.hasExpires() && result.expires && result.hasTtl();
          final ttl = expires ? now.add(Duration(seconds: result.ttl)) : null;
          _setState(SpinifyState$Connected(
            url: state.url,
            timestamp: now,
            client: result.hasClient() ? result.client : null,
            version: result.hasVersion() ? result.version : null,
            expires: expires,
            ttl: ttl,
            node: state.node,
            pingInterval: state.pingInterval,
            sendPong: state.sendPong,
            session: state.session,
            data: state.data,
          ));
          return SpinifyRefreshResult(
            expires: expires,
            ttl: ttl,
          );
        } else {
          throw StateError('Not connected');
        }
      },
    );
  }
}

/// Handler for websocket states.
@internal
base mixin SpinifyWSPBStateHandlerMixin
    on SpinifyWSPBTransportBase, SpinifyWSPBReplyMixin {
  // Subscribe to websocket state after first connection.
  /// Subscription to websocket state.
  StreamSubscription<WebSocketClientState>? _webSocketClosedStateSubscription;

  @override
  @nonVirtual
  SpinifyState get state => _state;

  @protected
  @nonVirtual
  SpinifyState _state = SpinifyState$Disconnected(
    timestamp: DateTime.now(),
    closeCode: null,
    closeReason: 'Not connected yet',
  );

  @override
  @nonVirtual
  final SpinifyChangeNotifier<SpinifyState> states = SpinifyChangeNotifier();

  @override
  void _initTransport() {
    super._initTransport();
  }

  /// Change state of spinify client.
  @protected
  @nonVirtual
  void _setState(SpinifyState state) {
    if (state == _state) return;
    states.notify(_state = state);
  }

  @protected
  @nonVirtual
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  void _handleWebSocketClosedStates(WebSocketClientState$Closed state) {
    _setState(
      SpinifyState$Disconnected(
        timestamp: DateTime.now(),
        closeCode: state.closeCode,
        closeReason: state.closeReason,
      ),
    );
    _failAllReplies(
      const SpinifyReplyException(
        replyCode: 3000,
        replyMessage: 'Connection closed',
        temporary: true,
      ),
      StackTrace.current,
    );
  }

  @override
  Future<void> connect(
    String url,
    ServerSubscriptionManager serverSubscriptionManager,
  ) {
    // Change state to connecting before connection.
    _setState(SpinifyState$Connecting(url: url));
    // Subscribe to websocket state after initialization.
    _webSocketClosedStateSubscription ??= _webSocket.stateChanges.closed.listen(
      _handleWebSocketClosedStates,
      cancelOnError: false,
    );
    return super.connect(url, serverSubscriptionManager);
  }

  @override
  Future<void> close() async {
    _webSocketClosedStateSubscription?.cancel().ignore();
    _setState(SpinifyState$Closed());
    await super.close();
    states.close();
  }
}

/// Handler for websocket messages and decode protobuf.
@internal
base mixin SpinifyWSPBHandlerMixin
    on
        SpinifyWSPBTransportBase,
        SpinifyWSPBSenderMixin,
        SpinifyWSPBPingPongMixin {
  /// Encoder protobuf commands to bytes.
  static const Converter<List<int>, Iterable<pb.Reply>> _replyDecoder =
      TransportProtobufDecoder();

  /// Subscription to websocket messages/data.
  StreamSubscription<List<int>>? _webSocketMessageSubscription;

  BigInt _receivedCount = BigInt.zero;
  BigInt _receivedSize = BigInt.zero;
  @override
  ({BigInt count, BigInt size}) get received =>
      (count: _receivedCount, size: _receivedSize);

  @override
  Future<void> connect(
    String url,
    ServerSubscriptionManager serverSubscriptionManager,
  ) {
    // Subscribe to websocket messages after first connection.
    _webSocketMessageSubscription ??= _webSocket.stream.bytes.listen(
      _handleWebSocketMessage,
      cancelOnError: false,
    );
    return super.connect(url, serverSubscriptionManager);
  }

  @protected
  @nonVirtual
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  void _handleWebSocketMessage(List<int> response) {
    _receivedCount += BigInt.one;
    _receivedSize += BigInt.from(response.length);
    final replies = _replyDecoder.convert(response);
    for (final reply in replies) {
      if (reply.hasId() && reply.id > 0) {
        logger.fine('Reply for command #${reply.id} received');
        _completeReply(reply);
      } else if (reply.hasPush()) {
        logger.info('Push message from server received');
        _onPush(reply.push);
      } else {
        logger.fine('Ping message from server received');
        _onPing(); // Every empty message from server is a ping.
      }
    }
  }

  @protected
  @nonVirtual
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  void _onPing() {
    _restartPingTimer();
    if (state case SpinifyState$Connected(:bool? sendPong)) {
      if (sendPong != true) return;
      _sendAsyncMessage(pb.PingRequest()).ignore();
      logger.fine('Pong message sent');
    }
  }

  /// Push can be sent to a client as part of Reply in case of bidirectional
  /// transport or without additional wrapping in case of unidirectional
  /// transports. ProtocolVersion2 uses channel and one of the possible concrete
  /// push messages.
  @protected
  @nonVirtual
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  void _onPush(pb.Push push) {
    final now = DateTime.now();
    final channel = push.hasChannel() ? push.channel : '';
    if (push.hasPub()) {
      events.notify($publicationDecode(push.channel)(push.pub));
    } else if (push.hasMessage()) {
      events.notify(
        SpinifyMessage(
          timestamp: now,
          channel: channel,
          data: push.message.hasData() ? push.message.data : const <int>[],
        ),
      );
    } else if (push.hasJoin()) {
      events.notify(
        SpinifyJoin(
          timestamp: now,
          channel: channel,
          info: $decodeClientInfo(push.join.info),
        ),
      );
    } else if (push.hasLeave()) {
      events.notify(
        SpinifyLeave(
          timestamp: now,
          channel: channel,
          info: $decodeClientInfo(push.join.info),
        ),
      );
    } else if (push.hasSubscribe()) {
      final positioned =
          push.subscribe.hasPositioned() && push.subscribe.positioned;
      final recoverable =
          push.subscribe.hasRecoverable() && push.subscribe.recoverable;
      events.notify(
        SpinifySubscribe(
          timestamp: now,
          channel: channel,
          positioned: positioned,
          recoverable: recoverable,
          data: push.subscribe.hasData() ? push.subscribe.data : const <int>[],
          streamPosition: (positioned || recoverable) &&
                  push.subscribe.hasOffset() &&
                  push.subscribe.hasEpoch()
              ? (offset: push.subscribe.offset, epoch: push.subscribe.epoch)
              : null,
        ),
      );
    } else if (push.hasUnsubscribe()) {
      events.notify(
        SpinifyUnsubscribe(
          timestamp: now,
          channel: channel,
          code: push.unsubscribe.hasCode() ? push.unsubscribe.code : 0,
          reason: push.unsubscribe.hasReason() ? push.unsubscribe.reason : 'OK',
        ),
      );
    } else if (push.hasConnect()) {
      final connect = push.connect;
      final expires =
          connect.hasExpires() && connect.expires && connect.hasTtl();
      events.notify(
        SpinifyConnect(
          timestamp: now,
          channel: channel,
          data: push.message.hasData() ? push.message.data : const <int>[],
          client: connect.hasClient() ? connect.client : '',
          version: connect.hasVersion() ? connect.version : '',
          ttl: expires ? now.add(Duration(seconds: connect.ttl)) : null,
          expires: expires,
          node: connect.hasNode() ? connect.node : null,
          pingInterval:
              connect.hasPing() ? Duration(seconds: connect.ping) : null,
          sendPong: connect.hasPong() ? connect.pong : null,
          session: connect.hasSession() ? connect.session : null,
        ),
      );
    } else if (push.hasDisconnect()) {
      events.notify(
        SpinifyDisconnect(
          timestamp: now,
          channel: channel,
          code: push.disconnect.hasCode() ? push.disconnect.code : 0,
          reason: push.disconnect.hasReason()
              ? push.disconnect.reason
              : 'disconnect from server',
          reconnect:
              push.disconnect.hasReconnect() && push.disconnect.reconnect,
        ),
      );
    } else if (push.hasRefresh()) {
      events.notify(SpinifyRefresh(
        timestamp: now,
        channel: channel,
        expires: push.refresh.hasExpires() && push.refresh.expires,
        ttl: push.refresh.hasTtl()
            ? now.add(Duration(seconds: push.refresh.ttl))
            : null,
      ));
    }
  }

  @override
  Future<void> close() async {
    await super.close();
    _webSocketMessageSubscription?.cancel().ignore();
  }
}

/// Mixin responsible for spinify subscriptions.
@internal
base mixin SpinifyWSPBSubscription
    on SpinifyWSPBTransportBase, SpinifyWSPBSenderMixin {
  @override
  Future<SubcibedOnChannel> subscribe(
    String channel,
    SpinifySubscriptionConfig config,
    SpinifyStreamPosition? since,
  ) async {
    if (!state.isConnected) {
      throw SpinifySubscriptionException(
        channel: channel,
        message: 'Spinify client is not connected',
      );
    }
    final request = pb.SubscribeRequest()
      ..channel = channel
      ..positioned = config.positioned
      ..recoverable = config.recoverable
      ..joinLeave = config.joinLeave;
    final token = await config.getToken?.call();
    assert(
      token == null || token.length > 5,
      'Spinify Subscription JWT is too short',
    );
    if (token != null && token.isNotEmpty) request.token = token;
    final data = await config.getPayload?.call();
    if (data != null) request.data = data;
    if (since != null) {
      request
        ..recover = true
        ..offset = since.offset
        ..epoch = since.epoch;
    } else {
      request.recover = false;
    }
    final pb.SubscribeResult result;
    try {
      result = await _sendMessage(request, pb.SubscribeResult())
          .timeout(config.timeout);
    } on TimeoutException {
      disconnect(
        DisconnectCode.timeout.code,
        'Timeout while subscribing to channel $channel',
      ).ignore();
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        SpinifySubscriptionException(
          channel: channel,
          message: 'Error while making subscribe request',
          error: error,
        ),
        stackTrace,
      );
    }
    final now = DateTime.now();
    final publicationDecoder = $publicationDecode(channel);
    final publications = result.publications.isEmpty
        ? _emptyPublicationsList
        : UnmodifiableListView<SpinifyPublication>(
            result.publications
                .map<SpinifyPublication>(publicationDecoder)
                .toList(growable: false),
          );
    final recoverable = result.hasRecoverable() && result.recoverable;
    final expires = result.hasExpires() && result.expires && result.hasTtl();
    return SubcibedOnChannel(
      channel: channel,
      expires: expires,
      ttl: expires ? now.add(Duration(seconds: result.ttl)) : null,
      recoverable: recoverable,
      since: recoverable && result.hasOffset() && result.hasEpoch()
          ? (offset: result.offset, epoch: result.epoch)
          : null,
      publications: publications,
      recovered: result.hasRecovered() && result.recovered,
      positioned: result.hasPositioned() && result.positioned,
      wasRecovering: result.hasWasRecovering() && result.wasRecovering,
      data: result.hasData() ? result.data : null,
    );
  }

  @override
  Future<void> unsubscribe(
    String channel,
    SpinifySubscriptionConfig config,
  ) async {
    if (_webSocket.state.readyState.isDisconnecting ||
        _webSocket.state.readyState.isClosed) {
      // Disconnected - do nothing.
      return;
    }
    final request = pb.UnsubscribeRequest()..channel = channel;
    await _sendMessage(request, pb.UnsubscribeResult()).timeout(config.timeout);
  }

  @override
  Future<void> publish(String channel, List<int> data) => _sendMessage(
      pb.PublishRequest()
        ..channel = channel
        ..data = data,
      pb.PublishResult());

  @override
  Future<SpinifyHistory> history(
    String channel, {
    int? limit,
    SpinifyStreamPosition? since,
    bool? reverse,
  }) async {
    final request = pb.HistoryRequest()..channel = channel;
    if (limit != null) request.limit = limit;
    if (reverse != null) request.reverse = reverse;
    if (since != null) {
      request.since = pb.StreamPosition()
        ..offset = since.offset
        ..epoch = since.epoch;
    }
    final result = await _sendMessage(request, pb.HistoryResult());
    final publicationDecoder = $publicationDecode(channel);
    return SpinifyHistory(
      publications: result.publications.isEmpty
          ? _emptyPublicationsList
          : UnmodifiableListView<SpinifyPublication>(
              result.publications
                  .map<SpinifyPublication>(publicationDecoder)
                  .toList(growable: false),
            ),
      since: (epoch: result.epoch, offset: result.offset),
    );
  }

  @override
  Future<SpinifyPresence> presence(String channel) =>
      _sendMessage(pb.PresenceRequest()..channel = channel, pb.PresenceResult())
          .then<SpinifyPresence>(
        (r) => SpinifyPresence(
          channel: channel,
          clients: UnmodifiableMapView<String, SpinifyClientInfo>(
            <String, SpinifyClientInfo>{
              for (final e in r.presence.entries)
                e.key: SpinifyClientInfo(
                  user: e.value.user,
                  client: e.value.client,
                  channelInfo: e.value.hasChanInfo() ? e.value.chanInfo : null,
                  connectionInfo:
                      e.value.hasConnInfo() ? e.value.connInfo : null,
                )
            },
          ),
        ),
      );

  @override
  Future<SpinifyPresenceStats> presenceStats(String channel) => _sendMessage(
              pb.PresenceStatsRequest()..channel = channel,
              pb.PresenceStatsResult())
          .then<SpinifyPresenceStats>(
        (r) => SpinifyPresenceStats(
          channel: channel,
          clients: r.hasNumClients() ? r.numClients : 0,
          users: r.hasNumUsers() ? r.numUsers : 0,
        ),
      );

  @override
  Future<SpinifySubRefreshResult> sendSubRefresh(
    String channel,
    String token,
  ) =>
      _sendMessage(
              pb.SubRefreshRequest()
                ..channel = channel
                ..token = token,
              pb.SubRefreshResult())
          .then<SpinifySubRefreshResult>(
        (r) {
          final expires = r.hasExpires() && r.expires && r.hasTtl();
          return SpinifySubRefreshResult(
            expires: expires,
            ttl: expires ? DateTime.now().add(Duration(seconds: r.ttl)) : null,
          );
        },
      );

  @override
  Future<List<int>> rpc(String method, List<int> data) => _sendMessage(
          pb.RPCRequest()
            ..method = method
            ..data = data,
          pb.RPCResult())
      .then<List<int>>((r) => r.hasData() ? r.data : const <int>[]);
}

/// To maintain connection alive and detect broken connections
/// server periodically sends empty commands to clients
/// and expects empty replies from them.
///
/// When client does not receive ping from a server for some
/// time it can consider connection broken and try to reconnect.
/// Usually a server sends pings every 25 seconds.
@internal
base mixin SpinifyWSPBPingPongMixin on SpinifyWSPBTransportBase {
  @protected
  @nonVirtual
  Timer? _pingTimer;

  @override
  Future<void> connect(
    String url,
    ServerSubscriptionManager serverSubscriptionManager,
  ) async {
    _tearDownPingTimer();
    await super.connect(url, serverSubscriptionManager);
    _restartPingTimer();
  }

  /// Start or restart keepalive timer,
  /// you should restart it after each received ping message.
  /// Or connection will be closed by timeout.
  @protected
  @nonVirtual
  void _restartPingTimer() {
    _tearDownPingTimer();
    if (state case SpinifyState$Connected(:Duration pingInterval)) {
      _pingTimer = Timer(
        pingInterval + _config.serverPingDelay,
        () => disconnect(
          DisconnectCode.badProtocol.code,
          'No ping from server',
        ),
      );
    }
  }

  /// Stop keepalive timer.
  @protected
  @nonVirtual
  void _tearDownPingTimer() => _pingTimer?.cancel();

  @override
  Future<void> close() async {
    _tearDownPingTimer();
    return super.close();
  }
}

final List<SpinifyPublication> _emptyPublicationsList =
    List<SpinifyPublication>.empty(growable: false);

/// Decode protobuf messages to Spinify models.
@internal
SpinifyPublication Function(pb.Publication publication) $publicationDecode(
  String channel,
) {
  final timestamp = DateTime.now();
  return (publication) => SpinifyPublication(
        timestamp: timestamp,
        channel: channel,
        offset: publication.hasOffset() ? publication.offset : null,
        data: publication.data,
        tags: publication.tags,
        info:
            publication.hasInfo() ? $decodeClientInfo(publication.info) : null,
      );
}

/// Decode protobuf client info to Spinify client info.
@internal
SpinifyClientInfo $decodeClientInfo(pb.ClientInfo info) => SpinifyClientInfo(
      client: info.client,
      user: info.user,
      channelInfo: info.hasChanInfo() ? info.chanInfo : null,
      connectionInfo: info.hasConnInfo() ? info.connInfo : null,
    );
