import 'dart:async';
import 'dart:convert';

import 'package:centrifuge_dart/src/model/exception.dart';
import 'package:centrifuge_dart/src/model/protobuf/client.pb.dart' as pb;
import 'package:centrifuge_dart/src/model/state.dart';
import 'package:centrifuge_dart/src/transport/transport_interface.dart';
import 'package:centrifuge_dart/src/transport/transport_protobuf_codec.dart';
import 'package:meta/meta.dart';
import 'package:protobuf/protobuf.dart' as pb;
import 'package:ws/ws.dart';

/// {@nodoc}
@internal
abstract base class CentrifugeWebSocketProtobufTransportBase
    implements ICentrifugeTransport {
  /// {@nodoc}
  CentrifugeWebSocketProtobufTransportBase({
    Duration? timeout,
    Map<String, Object?>? headers,
  })  : _timeout = timeout ?? const Duration(seconds: 15),
        _webSocket = WebSocketClient(
          WebSocketOptions.selector(
            js: () => WebSocketOptions.js(
              connectionRetryInterval: null,
              protocols: _$protocolsCentrifugeProtobuf,
              timeout: timeout ?? const Duration(seconds: 15),
              useBlobForBinary: false,
            ),
            vm: () => WebSocketOptions.vm(
              connectionRetryInterval: null,
              protocols: _$protocolsCentrifugeProtobuf,
              timeout: timeout,
              headers: headers,
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

  /// Timeout for connection and requests.
  /// {@nodoc}
  final Duration _timeout;

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
  Future<void> connect({
    required String url,
    required ({String name, String version}) client,
    FutureOr<String?> Function()? getToken,
    FutureOr<List<int>?> Function()? getPayload,
  }) async {}

  @override
  @mustCallSuper
  Future<void> disconnect() async {}

  @override
  @mustCallSuper
  Future<void> close() async {}
}

/// Class responsible for sending and receiving data from the server
/// through the Protobuf & WebSocket protocol.
/// {@nodoc}
@internal
final class CentrifugeWebSocketProtobufTransport
    extends CentrifugeWebSocketProtobufTransportBase
    with
        CentrifugeWebSocketProtobufReplyMixin,
        CentrifugeWebSocketStateHandlerMixin,
        CentrifugeWebSocketProtobufSenderMixin,
        CentrifugeWebSocketConnectionMixin,
        CentrifugeWebSocketProtobufHandlerMixin {
  /// {@nodoc}
  CentrifugeWebSocketProtobufTransport({super.timeout, super.headers});

  /// Current state of client.
  /// {@nodoc}
  @override
  @nonVirtual
  CentrifugeState get state => _state;

  @override
  Future<void> disconnect() async {
    await _webSocket.disconnect();
    await super.disconnect();
  }

  @override
  Future<void> close() async {
    await disconnect();
    await _webSocket.close();
    await super.close();
  }
}

/// Stored completer for responses.
/// {@nodoc}
typedef _ReplyCompleter = ({
  void Function(pb.Reply reply) complete,
  void Function(Object error, StackTrace stackTrace) fail,
});

/// Mixin responsible for holding reply completers.
/// {@nodoc}
@internal
base mixin CentrifugeWebSocketProtobufReplyMixin
    on CentrifugeWebSocketProtobufTransportBase {
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
            _timeout,
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
base mixin CentrifugeWebSocketProtobufSenderMixin
    on
        CentrifugeWebSocketProtobufTransportBase,
        CentrifugeWebSocketProtobufReplyMixin {
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
base mixin CentrifugeWebSocketConnectionMixin
    on
        CentrifugeWebSocketProtobufTransportBase,
        CentrifugeWebSocketProtobufSenderMixin,
        CentrifugeWebSocketStateHandlerMixin {
  @override
  Future<void> connect({
    required String url,
    required ({String name, String version}) client,
    FutureOr<String?> Function()? getToken,
    FutureOr<List<int>?> Function()? getPayload,
  }) async {
    try {
      await super.connect(
        url: url,
        client: client,
        getToken: getToken,
        getPayload: getPayload,
      );
      await _webSocket.connect(url);
      final request = pb.ConnectRequest();
      final token = await getToken?.call();
      assert(token == null || token.length > 5, 'Centrifuge JWT is too short');
      if (token != null) request.token = token;
      final payload = await getPayload?.call();
      if (payload != null) request.data = payload;
      request
        ..name = client.name
        ..version = client.version;
      // TODO(plugfox): add subscriptions.
      // TODO(plugfox): Send request.
      final result = await _sendMessage(request, pb.ConnectResult());
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
      ));
    } on Object {
      _setState(CentrifugeState$Disconnected());
      rethrow;
    }
  }
}

/// Handler for websocket states.
/// {@nodoc}
@internal
base mixin CentrifugeWebSocketStateHandlerMixin
    on
        CentrifugeWebSocketProtobufTransportBase,
        CentrifugeWebSocketProtobufReplyMixin {
  // Subscribe to websocket state after first connection.
  /// Subscription to websocket state.
  /// {@nodoc}
  StreamSubscription<WebSocketClientState>? _webSocketClosedStateSubscription;

  /// {@nodoc}
  @override
  @nonVirtual
  Stream<CentrifugeState> get states => _stateController.stream;

  /// {@nodoc}
  @protected
  @nonVirtual
  late CentrifugeState _state;

  /// State controller.
  /// {@nodoc}
  @protected
  @nonVirtual
  late final StreamController<CentrifugeState> _stateController;

  @override
  void _initTransport() {
    // Init state controller.
    _state = CentrifugeState$Disconnected();
    _stateController = StreamController<CentrifugeState>.broadcast(
      onListen: () => _stateController.add(_state),
      onCancel: () => _stateController.close(),
    );
    super._initTransport();
  }

  /// Change state of centrifuge client.
  /// {@nodoc}
  @protected
  @nonVirtual
  void _setState(CentrifugeState state) {
    if (_state.type == state.type) return;
    _stateController.add(_state = state);
  }

  @protected
  @nonVirtual
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  void _handleWebSocketStateChange(WebSocketClientState$Closed state) {
    _setState(CentrifugeState$Disconnected());
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
  Future<void> connect({
    required String url,
    required ({String name, String version}) client,
    FutureOr<String?> Function()? getToken,
    FutureOr<List<int>?> Function()? getPayload,
  }) {
    // Change state to connecting before connection.
    _setState(CentrifugeState$Connecting(url: url));
    // Subscribe to websocket state after initialization.
    _webSocketClosedStateSubscription ??= _webSocket.stateChanges.closed.listen(
      _handleWebSocketStateChange,
      cancelOnError: false,
    );
    return super.connect(
      url: url,
      client: client,
      getToken: getToken,
      getPayload: getPayload,
    );
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
base mixin CentrifugeWebSocketProtobufHandlerMixin
    on
        CentrifugeWebSocketProtobufTransportBase,
        CentrifugeWebSocketProtobufReplyMixin,
        CentrifugeWebSocketStateHandlerMixin,
        CentrifugeWebSocketProtobufSenderMixin {
  /// Encoder protobuf commands to bytes.
  /// {@nodoc}
  static const Converter<List<int>, Iterable<pb.Reply>> _replyDecoder =
      TransportProtobufDecoder();

  /// Subscription to websocket messages/data.
  /// {@nodoc}
  StreamSubscription<List<int>>? _webSocketMessageSubscription;

  // TODO(plugfox): add publications stream.
  final StreamController<Object> _pushController =
      StreamController<Object>.broadcast();

  @override
  Future<void> connect({
    required String url,
    required ({String name, String version}) client,
    FutureOr<String?> Function()? getToken,
    FutureOr<List<int>?> Function()? getPayload,
  }) {
    // Subscribe to websocket messages after first connection.
    _webSocketMessageSubscription ??= _webSocket.stream.bytes.listen(
      _handleWebSocketMessage,
      cancelOnError: false,
    );
    return super.connect(
      url: url,
      client: client,
      getToken: getToken,
      getPayload: getPayload,
    );
  }

  /// {@nodoc}
  @protected
  @nonVirtual
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  void _handleWebSocketMessage(List<int> response) {
    final replies = _replyDecoder.convert(response);
    for (final reply in replies) {
      if (reply.hasPush()) {
        _pushController.add(reply.push);
      }
      if (reply.id > 0) {
        _completeReply(reply);
        switch (reply.id) {
          case > 0:
            _completeReply(reply);
          default:
        }
      } else if (reply.hasPing()) {
        _onPing(reply.ping);
      } else if (reply.hasPush()) {
        _onPush(reply.push);
      }
    }
  }

  @protected
  @nonVirtual
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  void _onPing(pb.PingResult ping) {
    if (state case CentrifugeState$Connected(:bool? sendPong)) {
      if (sendPong != true) return;
      _sendAsyncMessage(pb.PingRequest()).ignore();
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
    _pushController.close().ignore();
  }
}
