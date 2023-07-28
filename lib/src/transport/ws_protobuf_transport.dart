import 'dart:async';
import 'dart:convert';

import 'package:centrifuge_dart/centrifuge.dart';
import 'package:centrifuge_dart/src/client/disconnect_code.dart';
import 'package:centrifuge_dart/src/model/protobuf/client.pb.dart' as pb;
import 'package:centrifuge_dart/src/model/stream_position.dart';
import 'package:centrifuge_dart/src/subscription/subcibed_on_channel.dart';
import 'package:centrifuge_dart/src/transport/transport_interface.dart';
import 'package:centrifuge_dart/src/transport/transport_protobuf_codec.dart';
import 'package:centrifuge_dart/src/util/logger.dart' as logger;
import 'package:centrifuge_dart/src/util/notifier.dart';
import 'package:meta/meta.dart';
import 'package:protobuf/protobuf.dart' as pb;
import 'package:ws/ws.dart';

/// {@nodoc}
@internal
abstract base class CentrifugeWSPBTransportBase
    implements ICentrifugeTransport {
  /// {@nodoc}
  CentrifugeWSPBTransportBase({
    required CentrifugeConfig config,
  })  : _config = config,
        _webSocket = WebSocketClient(
          WebSocketOptions.selector(
            js: () => WebSocketOptions.js(
              connectionRetryInterval: null,
              protocols: _$protocolsCentrifugeProtobuf,
              timeout: config.timeout,
              useBlobForBinary: false,
            ),
            vm: () => WebSocketOptions.vm(
              connectionRetryInterval: null,
              protocols: _$protocolsCentrifugeProtobuf,
              timeout: config.timeout,
              headers: config.headers,
            ),
          ),
        ) {
    _initTransport();
  }

  /// Protocols for websocket.
  /// {@nodoc}
  static const List<String> _$protocolsCentrifugeProtobuf = <String>[
    'centrifuge-protobuf'
  ];

  /// Centrifuge config.
  /// {@nodoc}
  final CentrifugeConfig _config;

  /// Init transport, override this method to add custom logic.
  /// {@nodoc}
  @protected
  @mustCallSuper
  void _initTransport() {}

  /// Websocket client.
  /// {@nodoc}
  @nonVirtual
  final WebSocketClient _webSocket;

  @override
  @mustCallSuper
  Future<void> connect(String url) async {}

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
  }
}

/// Class responsible for sending and receiving data from the server
/// through the Protobuf & WebSocket protocol.
/// {@nodoc}
@internal
// ignore: lines_longer_than_80_chars
final class CentrifugeWSPBTransport = CentrifugeWSPBTransportBase
    with
        CentrifugeWSPBReplyMixin,
        CentrifugeWSPBStateHandlerMixin,
        CentrifugeWSPBSenderMixin,
        CentrifugeWSPBConnectionMixin,
        CentrifugeWSPBPingPongMixin,
        CentrifugeWSPBSubscription,
        CentrifugeWSPBHandlerMixin;

/// Stored completer for responses.
/// {@nodoc}
typedef _ReplyCompleter = ({
  void Function(pb.Reply reply) complete,
  void Function(Object error, StackTrace stackTrace) fail,
});

/// Mixin responsible for holding reply completers.
/// {@nodoc}
@internal
base mixin CentrifugeWSPBReplyMixin on CentrifugeWSPBTransportBase {
  /// Completers for messages by id.
  /// Contains timer for timeout and completer for response.
  /// {@nodoc}
  final Map<int, _ReplyCompleter> _replyCompleters = <int, _ReplyCompleter>{};

  /// Observe reply future by command id.
  /// {@nodoc}
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
  /// {@nodoc}
  void _completeReply(pb.Reply reply) =>
      _replyCompleters.remove(reply.id)?.complete(reply);

  /// Fail all replies.
  /// {@nodoc}
  void _failAllReplies(Object error, StackTrace stackTrace) {
    for (final completer in _replyCompleters.values) {
      completer.fail(error, stackTrace);
    }
    _replyCompleters.clear();
  }
}

/// Mixin responsible for sending data through websocket with protobuf.
/// {@nodoc}
@internal
base mixin CentrifugeWSPBSenderMixin
    on CentrifugeWSPBTransportBase, CentrifugeWSPBReplyMixin {
  /// Encoder protobuf commands to bytes.
  /// {@nodoc}
  static const Converter<pb.Command, List<int>> _commandEncoder =
      TransportProtobufEncoder();

  /// Counter for messages.
  /// {@nodoc}
  int _messageId = 1;

  /// {@nodoc}
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
    await _sendCommand(command);
    final reply = await future;
    if (reply.hasError()) {
      throw CentrifugeReplyException(
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

  /// {@nodoc}
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

  Future<void> _sendCommand(pb.Command command) {
    if (!_webSocket.state.readyState.isOpen) throw StateError('Not connected');
    final data = _commandEncoder.convert(command);
    return _webSocket.add(data);
  }
}

/// Mixin responsible for connection.
/// {@nodoc}
@internal
base mixin CentrifugeWSPBConnectionMixin
    on
        CentrifugeWSPBTransportBase,
        CentrifugeWSPBSenderMixin,
        CentrifugeWSPBStateHandlerMixin {
  @override
  Future<void> connect(String url) async {
    try {
      await super.connect(url);
      await _webSocket.connect(url);
      final request = pb.ConnectRequest();
      final token = await _config.getToken?.call();
      assert(token == null || token.length > 5, 'Centrifuge JWT is too short');
      if (token != null) request.token = token;
      final payload = await _config.getPayload?.call();
      if (payload != null) request.data = payload;
      request
        ..name = _config.client.name
        ..version = _config.client.version;
      // TODO(plugfox): add subscriptions.
      // TODO(plugfox): Send request.
      final pb.ConnectResult result;
      try {
        result = await _sendMessage(request, pb.ConnectResult());
      } on Object catch (error, stackTrace) {
        Error.throwWithStackTrace(
          CentrifugeConnectionException(error),
          stackTrace,
        );
      }
      if (!_webSocket.state.readyState.isOpen) {
        throw StateError('Connection closed during connection process');
      }
      final now = DateTime.now();
      _setState(CentrifugeState$Connected(
        url: url,
        timestamp: now,
        client: result.hasClient() ? result.client : null,
        version: result.hasVersion() ? result.version : null,
        expires: result.hasExpires() ? result.expires : null,
        ttl: result.hasTtl() ? now.add(Duration(seconds: result.ttl)) : null,
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
}

/// Handler for websocket states.
/// {@nodoc}
@internal
base mixin CentrifugeWSPBStateHandlerMixin
    on CentrifugeWSPBTransportBase, CentrifugeWSPBReplyMixin {
  // Subscribe to websocket state after first connection.
  /// Subscription to websocket state.
  /// {@nodoc}
  StreamSubscription<WebSocketClientState>? _webSocketClosedStateSubscription;

  /// {@nodoc}
  @override
  @nonVirtual
  late final CentrifugeValueNotifier<CentrifugeState> states =
      CentrifugeValueNotifier(CentrifugeState$Disconnected(
    timestamp: DateTime.now(),
    closeCode: null,
    closeReason: 'Not connected yet',
  ));

  @override
  void _initTransport() {
    super._initTransport();
  }

  /// Change state of centrifuge client.
  /// {@nodoc}
  @protected
  @nonVirtual
  void _setState(CentrifugeState state) {
    states.notify(state);
  }

  @protected
  @nonVirtual
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  void _handleWebSocketClosedStates(WebSocketClientState$Closed state) {
    _setState(
      CentrifugeState$Disconnected(
        timestamp: DateTime.now(),
        closeCode: state.closeCode,
        closeReason: state.closeReason,
      ),
    );
    _failAllReplies(
      const CentrifugeReplyException(
        replyCode: 3000,
        replyMessage: 'Connection closed',
        temporary: true,
      ),
      StackTrace.current,
    );
  }

  @override
  Future<void> connect(String url) {
    // Change state to connecting before connection.
    _setState(CentrifugeState$Connecting(url: url));
    // Subscribe to websocket state after initialization.
    _webSocketClosedStateSubscription ??= _webSocket.stateChanges.closed.listen(
      _handleWebSocketClosedStates,
      cancelOnError: false,
    );
    return super.connect(url);
  }

  @override
  Future<void> close() async {
    _webSocketClosedStateSubscription?.cancel().ignore();
    _setState(CentrifugeState$Closed());
    await super.close();
  }
}

/// Handler for websocket messages and decode protobuf.
/// {@nodoc}
@internal
base mixin CentrifugeWSPBHandlerMixin
    on
        CentrifugeWSPBTransportBase,
        CentrifugeWSPBSenderMixin,
        CentrifugeWSPBPingPongMixin {
  /// Encoder protobuf commands to bytes.
  /// {@nodoc}
  static const Converter<List<int>, Iterable<pb.Reply>> _replyDecoder =
      TransportProtobufDecoder();

  /// Subscription to websocket messages/data.
  /// {@nodoc}
  StreamSubscription<List<int>>? _webSocketMessageSubscription;

  @override
  Future<void> connect(String url) {
    // Subscribe to websocket messages after first connection.
    _webSocketMessageSubscription ??= _webSocket.stream.bytes.listen(
      _handleWebSocketMessage,
      cancelOnError: false,
    );
    return super.connect(url);
  }

  /// {@nodoc}
  @protected
  @nonVirtual
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  void _handleWebSocketMessage(List<int> response) {
    final replies = _replyDecoder.convert(response);
    for (final reply in replies) {
      if (reply.id > 0) {
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
    if (states.value case CentrifugeState$Connected(:bool? sendPong)) {
      if (sendPong != true) return;
      _sendAsyncMessage(pb.PingRequest()).ignore();
      logger.fine('Pong message sent');
    }
  }

  @protected
  @nonVirtual
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  void _onPush(pb.Push push) {
    if (push.hasPub()) {
      //_handlePub(push.channel, push.pub);
    } else if (push.hasJoin()) {
      //_handleJoin(push.channel, push.join);
    } else if (push.hasLeave()) {
      //_handleLeave(push.channel, push.leave);
    } else if (push.hasSubscribe()) {
      //_handleSubscribe(push.channel, push.subscribe);
    } else if (push.hasUnsubscribe()) {
      //_handleUnsubscribe(push.channel, push.unsubscribe);
    } else if (push.hasMessage()) {
      //_handleMessage(push.message);
    } else if (push.hasDisconnect()) {
      //_handleDisconnect(push.disconnect);
    }
  }

  @override
  Future<void> close() async {
    await super.close();
    _webSocketMessageSubscription?.cancel().ignore();
  }
}

/// Mixin responsible for centrifuge subscriptions.
/// {@nodoc}
@internal
base mixin CentrifugeWSPBSubscription
    on CentrifugeWSPBTransportBase, CentrifugeWSPBSenderMixin {
  @override
  Future<SubcibedOnChannel> subscribe(
    String channel,
    CentrifugeSubscriptionConfig config,
    CentrifugeStreamPosition? since,
  ) async {
    if (!states.value.isConnected) {
      throw CentrifugeSubscriptionException(
        channel: channel,
        message: 'Centrifuge client is not connected',
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
      'Centrifuge Subscription JWT is too short',
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
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        CentrifugeSubscriptionException(
          channel: channel,
          message: 'Error while making subscribe request',
          error: error,
        ),
        stackTrace,
      );
    }
    final now = DateTime.now();
    final publications = <CentrifugePublication>[
      for (final pub in result.publications)
        CentrifugePublication(
          offset: pub.offset,
          data: pub.data,
          info: pub.hasInfo()
              ? CentrifugeClientInfo(
                  channelInfo: pub.info.chanInfo,
                  client: pub.info.client,
                  user: pub.info.user,
                  connectionInfo: pub.info.connInfo,
                )
              : null,
        ),
    ];
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
}

/// To maintain connection alive and detect broken connections
/// server periodically sends empty commands to clients
/// and expects empty replies from them.
///
/// When client does not receive ping from a server for some
/// time it can consider connection broken and try to reconnect.
/// Usually a server sends pings every 25 seconds.
/// {@nodoc}
@internal
base mixin CentrifugeWSPBPingPongMixin on CentrifugeWSPBTransportBase {
  @protected
  @nonVirtual
  Timer? _pingTimer;

  @override
  Future<void> connect(String url) async {
    _tearDownPingTimer();
    await super.connect(url);
    _restartPingTimer();
  }

  /// Start or restart keepalive timer,
  /// you should restart it after each received ping message.
  /// Or connection will be closed by timeout.
  /// {@nodoc}
  @protected
  @nonVirtual
  void _restartPingTimer() {
    _tearDownPingTimer();
    if (states.value case CentrifugeState$Connected(:Duration pingInterval)) {
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
