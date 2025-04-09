//ignore_for_file: unintended_html_in_doc_comment

import 'dart:convert';

import 'package:protobuf/protobuf.dart' as pb;

import '../model/channel_event.dart';
import '../model/client_info.dart';
import '../model/codec.dart';
import '../model/command.dart';
import '../model/config.dart';
import '../model/reply.dart';
import '../model/stream_position.dart';
import 'client.pb.dart' as pb;

/// Default protobuf codec for Spinify.
final class SpinifyProtobufCodec implements SpinifyCodec {
  /// Default protobuf codec for Spinify.
  SpinifyProtobufCodec([SpinifyLogger? logger])
      : decoder = SpinifyProtobufReplyDecoder(logger),
        encoder = SpinifyProtobufCommandEncoder(logger);

  @override
  String get protocol => 'centrifuge-protobuf';

  @override
  final Converter<List<int>, Iterable<SpinifyReply>> decoder;

  @override
  final Converter<SpinifyCommand, List<int>> encoder;
}

/// SpinifyCommand --> List<int> encoder.
final class SpinifyProtobufCommandEncoder
    extends Converter<SpinifyCommand, List<int>> {
  /// SpinifyCommand --> List<int> encoder.
  const SpinifyProtobufCommandEncoder([this.logger]);

  /// Logger function to use for logging.
  /// If not specified, the logger will be disabled.
  /// The logger function is called with the following arguments:
  /// - [level] - the log verbose level 0..6
  ///  * 0 - debug
  ///  * 1 - transport
  ///  * 2 - config
  ///  * 3 - info
  ///  * 4 - warning
  ///  * 5 - error
  ///  * 6 - critical
  /// - [event] - the log event, unique type of log event
  /// - [message] - the log message
  /// - [context] - the log context data
  final SpinifyLogger? logger;

  @override
  List<int> convert(SpinifyCommand input) {
    final cmd = pb.Command(id: input.id);
    switch (input) {
      case SpinifySendRequest send:
        cmd.send = pb.SendRequest(
          data: send.data,
        );
      case SpinifyRPCRequest rpc:
        cmd.rpc = pb.RPCRequest(
          data: rpc.data,
          method: rpc.method,
        );
      case SpinifyPingRequest _:
        cmd.ping = pb.PingRequest();
      case SpinifyConnectRequest connect:
        // Create a ConnectRequest object
        final request = pb.ConnectRequest(
          token: connect.token,
          data: connect.data,
          name: connect.name,
          version: connect.version,
        );

        // Add connection headers to the request
        // if they are not null and not empty
        final subs = connect.subs;
        if (subs != null && subs.isNotEmpty)
          request.subs.addAll({
            for (final value in subs.values)
              value.channel: pb.SubscribeRequest(
                channel: value.channel,
                token: value.token,
                recover: value.recover,
                epoch: value.epoch,
                offset: value.offset,
                data: value.data,
                positioned: value.positioned,
                recoverable: value.recoverable,
                joinLeave: value.joinLeave,
              )
          });

        // Add headers to the request
        // if they are not null and not empty
        final headers = connect.headers;
        if (headers != null && headers.isNotEmpty)
          request.headers.addAll(headers);

        cmd.connect = request;
      case SpinifySubscribeRequest subscribe:
        cmd.subscribe = pb.SubscribeRequest(
          channel: subscribe.channel,
          token: subscribe.token,
          recover: subscribe.recover,
          epoch: subscribe.epoch,
          offset: subscribe.offset,
          data: subscribe.data,
          positioned: subscribe.positioned,
          recoverable: subscribe.recoverable,
          joinLeave: subscribe.joinLeave,
        );
      case SpinifyUnsubscribeRequest unsubscribe:
        cmd.unsubscribe = pb.UnsubscribeRequest(
          channel: unsubscribe.channel,
        );
      case SpinifyPublishRequest publish:
        cmd.publish = pb.PublishRequest(
          channel: publish.channel,
          data: publish.data,
        );
      case SpinifyPresenceRequest presence:
        cmd.presence = pb.PresenceRequest(
          channel: presence.channel,
        );
      case SpinifyPresenceStatsRequest presenceStats:
        cmd.presenceStats = pb.PresenceStatsRequest(
          channel: presenceStats.channel,
        );
      case SpinifyHistoryRequest history:
        cmd.history = pb.HistoryRequest(
          channel: history.channel,
          limit: history.limit,
          since: switch (history.since) {
            SpinifyStreamPosition since => pb.StreamPosition(
                offset: since.offset,
                epoch: since.epoch,
              ),
            null => null,
          },
          reverse: history.reverse,
        );
      case SpinifyRefreshRequest refresh:
        cmd.refresh = pb.RefreshRequest(
          token: refresh.token,
        );
      case SpinifySubRefreshRequest subRefresh:
        cmd.subRefresh = pb.SubRefreshRequest(
          channel: subRefresh.channel,
          token: subRefresh.token,
        );
    }
    final commandData = cmd.writeToBuffer();
    /* final writer = pb.CodedBufferWriter()
      ..writeInt32NoTag(
          commandData.lengthInBytes); //..writeRawBytes(commandData);
    final bytes = writer.toBuffer() + commandData;
    return bytes; */
    return (pb.CodedBufferWriter()
          ..writeInt32NoTag(commandData.lengthInBytes)
          ..writeRawBytes(commandData))
        .toBuffer();
  }
}

/// Protobuf List<int> --> Iterable<SpinifyReply> decoder.
final class SpinifyProtobufReplyDecoder
    extends Converter<List<int>, Iterable<SpinifyReply>> {
  /// List<int> --> Iterable<SpinifyReply> decoder.
  const SpinifyProtobufReplyDecoder([this.logger]);

  /// Logger function to use for logging.
  /// If not specified, the logger will be disabled.
  /// The logger function is called with the following arguments:
  /// - [level] - the log verbose level 0..6
  ///  * 0 - debug
  ///  * 1 - transport
  ///  * 2 - config
  ///  * 3 - info
  ///  * 4 - warning
  ///  * 5 - error
  ///  * 6 - critical
  /// - [event] - the log event, unique type of log event
  /// - [message] - the log message
  /// - [context] - the log context data
  final SpinifyLogger? logger;

  @override
  Iterable<SpinifyReply> convert(List<int> input) sync* {
    if (input.isEmpty) return;
    final reader = pb.CodedBufferReader(input);
    while (!reader.isAtEnd()) {
      try {
        final message = pb.Reply();
        reader.readMessage(message, pb.ExtensionRegistry.EMPTY);
        /* assert(() {
          print('Reply < ${message.toProto3Json()}');
          return true;
        }()); */
        if (message.hasPush()) {
          yield _decodePush(message.push);
        } else if (message.hasId() && message.id > 0) {
          yield _decodeReply(message);
        } else if (message.hasError()) {
          // coverage:ignore-start
          final error = message.error;
          yield SpinifyErrorResult(
            id: message.hasId() ? message.id : 0,
            timestamp: DateTime.now(),
            code: error.code,
            message: error.message,
            temporary: !error.hasTemporary() || error.temporary,
          );
          // coverage:ignore-end
        } else {
          yield SpinifyServerPing(
            timestamp: DateTime.now(),
          );
        }
      } on Object catch (error, stackTrace) {
        // coverage:ignore-start
        logger?.call(
          const SpinifyLogLevel.warning(),
          'protobuf_reply_decoder_error',
          'Error decoding reply',
          <String, Object?>{
            'error': error,
            'stackTrace': stackTrace,
            'input': input,
          },
        );
        // coverage:ignore-end
      }
    }

    assert(reader.isAtEnd(), 'Data is not fully consumed');
  }

  /*
    Publication pub = 4;
    Join join = 5;
    Leave leave = 6;
    Unsubscribe unsubscribe = 7;
    Message message = 8;
    Subscribe subscribe = 9;
    Connect connect = 10;
    Disconnect disconnect = 11;
    Refresh refresh = 12;
  */
  static SpinifyReply _decodePush(pb.Push push) {
    final channel = push.hasChannel() ? push.channel : '';
    final now = DateTime.now();
    final SpinifyChannelEvent event;
    if (push.hasPub()) {
      event = SpinifyPublication(
        timestamp: DateTime.now(),
        channel: channel,
        data: push.pub.hasData() ? push.pub.data : const <int>[],
        info: _decodeClientInfo(push.pub.info),
        offset: push.pub.hasOffset() ? push.pub.offset : null,
        tags: push.pub.tags,
      );
    } else if (push.hasJoin()) {
      event = SpinifyJoin(
        timestamp: DateTime.now(),
        channel: channel,
        info: _decodeClientInfo(push.join.info),
      );
    } else if (push.hasLeave()) {
      event = SpinifyLeave(
        timestamp: DateTime.now(),
        channel: channel,
        info: _decodeClientInfo(push.leave.info),
      );
    } else if (push.hasUnsubscribe()) {
      event = SpinifyUnsubscribe(
        timestamp: DateTime.now(),
        channel: channel,
        code: push.unsubscribe.code,
        reason: push.unsubscribe.reason,
      );
    } else if (push.hasMessage()) {
      event = SpinifyMessage(
        timestamp: DateTime.now(),
        channel: channel,
        data: push.message.data,
      );
    } else if (push.hasSubscribe()) {
      event = SpinifySubscribe(
        timestamp: DateTime.now(),
        channel: channel,
        recoverable: push.subscribe.recoverable,
        data: push.subscribe.hasData() ? push.subscribe.data : null,
        positioned: push.subscribe.positioned,
        since: (
          offset: push.subscribe.offset,
          epoch: push.subscribe.epoch,
        ),
      );
    } else if (push.hasConnect()) {
      final pb.Connect(:expires, :ttl, :ping) = push.connect;
      final bool expBool;
      final DateTime? ttlDT;
      if (expires == true && ttl > 0) {
        expBool = true;
        ttlDT = now.add(Duration(seconds: ttl));
      } else if (expires != true) {
        expBool = false;
        ttlDT = null;
      } else {
        expBool = false;
        ttlDT = null;
        assert(false, 'Connection expires is invalid'); // coverage:ignore-line
      }
      Duration? pingInterval;
      if (ping > 0) {
        pingInterval = Duration(seconds: ping);
      } else {
        assert(false, 'Ping interval is invalid'); // coverage:ignore-line
      }
      event = SpinifyConnect(
        channel: channel,
        timestamp: DateTime.now(),
        client: push.connect.client,
        version: push.connect.version,
        expires: expBool,
        ttl: ttlDT,
        data: push.connect.hasData() ? push.connect.data : null,
        node: push.connect.node,
        pingInterval: pingInterval,
        sendPong: push.connect.pong == true,
        session: push.connect.session,
      );
    } else if (push.hasDisconnect()) {
      final code = push.disconnect.code;
      event = SpinifyDisconnect(
        timestamp: DateTime.now(),
        reason: push.disconnect.hasReason()
            ? push.disconnect.reason
            : 'Server disconnecting',
        channel: channel,
        code: code,
        reconnect: push.disconnect.hasReconnect()
            ? push.disconnect.reconnect
            : code < 3500 || code >= 5000 || (code >= 4000 && code < 4500),
      );
    } else if (push.hasRefresh()) {
      final pb.Refresh(:expires, :ttl) = push.refresh;
      final bool expBool;
      final DateTime? ttlDT;
      if (expires == true && ttl > 0) {
        expBool = true;
        ttlDT = now.add(Duration(seconds: ttl));
      } else if (expires != true) {
        expBool = false;
        ttlDT = null;
      } else {
        expBool = false;
        ttlDT = null;
        assert(false, 'Connection refresh is invalid'); // coverage:ignore-line
      }
      event = SpinifyRefresh(
        timestamp: DateTime.now(),
        channel: channel,
        expires: expBool,
        ttl: ttlDT,
      );
    } else {
      throw UnimplementedError('Unsupported push type'); // coverage:ignore-line
    }
    return SpinifyPush(
      timestamp: now,
      event: event,
    );
  }

  static SpinifyClientInfo _decodeClientInfo(pb.ClientInfo info) =>
      SpinifyClientInfo(
        user: info.user,
        client: info.client,
        channelInfo: info.chanInfo,
        connectionInfo: info.connInfo,
      );

  /*
    ConnectResult connect = 5;
    SubscribeResult subscribe = 6;
    UnsubscribeResult unsubscribe = 7;
    PublishResult publish = 8;
    PresenceResult presence = 9;
    PresenceStatsResult presence_stats = 10;
    HistoryResult history = 11;
    RPCResult rpc = 13;
    RefreshResult refresh = 14;
    SubRefreshResult sub_refresh = 15;
  */
  static SpinifyReply _decodeReply(pb.Reply reply) {
    final now = DateTime.now();
    final id = reply.id;

    SpinifySubscribeResult decodeSubscribe(
      pb.SubscribeResult sub, {
      String channel = '',
    }) {
      final pb.SubscribeResult(:expires, :ttl) = sub;
      final bool expBool;
      final DateTime? ttlDT;
      if (expires == true && ttl > 0) {
        expBool = true;
        ttlDT = now.add(Duration(seconds: ttl));
      } else if (expires != true) {
        expBool = false;
        ttlDT = null;
      } else {
        expBool = false;
        ttlDT = null;
        assert(false, 'Connection expires is invalid'); // coverage:ignore-line
      }
      return SpinifySubscribeResult(
        id: id,
        timestamp: now,
        expires: expBool,
        ttl: ttlDT,
        data: sub.hasData() ? sub.data : null,
        recoverable: sub.recoverable,
        publications: <SpinifyPublication>[
          for (final pub in sub.publications)
            SpinifyPublication(
              timestamp: now,
              // SpinifyPublication in SubscribeResult do not
              // have the "channel" field - I should fill it in manually
              // by copying the channel from the SubscribeRequest
              channel: '',
              data: pub.hasData() ? pub.data : const <int>[],
              info: _decodeClientInfo(pub.info),
              offset: pub.offset,
              tags: pub.tags,
            ),
        ],
        positioned: sub.positioned,
        recovered: sub.recovered,
        since: (
          offset: sub.offset,
          epoch: sub.epoch,
        ),
        wasRecovering: sub.wasRecovering,
      );
    }

    if (reply.hasConnect()) {
      final connect = reply.connect;
      final pb.ConnectResult(:expires, :ttl, :ping) = connect;
      final bool expBool;
      final DateTime? ttlDT;
      if (expires == true && ttl > 0) {
        expBool = true;
        ttlDT = now.add(Duration(seconds: ttl));
      } else if (expires != true) {
        expBool = false;
        ttlDT = null;
      } else {
        expBool = false;
        ttlDT = null;
        assert(false, 'Connection expires is invalid'); // coverage:ignore-line
      }
      Duration? pingInterval;
      if (ping > 0) {
        pingInterval = Duration(seconds: ping);
      } else {
        assert(false, 'Ping interval is invalid'); // coverage:ignore-line
        pingInterval = const Duration(seconds: 25);
      }
      return SpinifyConnectResult(
        id: id,
        timestamp: now,
        client: connect.client,
        version: connect.version,
        expires: expBool,
        ttl: ttlDT,
        data: connect.hasData() ? connect.data : null,
        subs: switch (connect.subs) {
          Map<String, pb.SubscribeResult> map when map.isNotEmpty =>
            <String, SpinifySubscribeResult>{
              for (final e in map.entries)
                e.key: decodeSubscribe(e.value, channel: e.key),
            },
          _ => null,
        },
        pingInterval: pingInterval,
        sendPong: connect.pong,
        session: connect.session,
        node: connect.node,
      );
    } else if (reply.hasSubscribe()) {
      return decodeSubscribe(reply.subscribe);
    } else if (reply.hasUnsubscribe()) {
      return SpinifyUnsubscribeResult(
        id: id,
        timestamp: now,
      );
    } else if (reply.hasPublish()) {
      return SpinifyPublishResult(
        id: id,
        timestamp: now,
      );
    } else if (reply.hasPresence()) {
      final presence = reply.presence.presence;
      return SpinifyPresenceResult(
          id: id,
          timestamp: now,
          presence: <String, SpinifyClientInfo>{
            for (final e in presence.entries) e.key: _decodeClientInfo(e.value),
          });
    } else if (reply.hasPresenceStats()) {
      final presenceStats = reply.presenceStats;
      return SpinifyPresenceStatsResult(
        id: id,
        timestamp: now,
        numClients: presenceStats.numClients,
        numUsers: presenceStats.numUsers,
      );
    } else if (reply.hasHistory()) {
      final history = reply.history;
      return SpinifyHistoryResult(
        id: id,
        timestamp: now,
        since: (
          offset: history.offset,
          epoch: history.epoch,
        ),
        publications: <SpinifyPublication>[
          for (final pub in history.publications)
            SpinifyPublication(
              timestamp: now,
              // SpinifyPublication in HistoryResult do not
              // have the "channel" field - I should fill it in manually
              // by copying the channel from the SubscribeRequest
              channel: '',
              data: pub.hasData() ? pub.data : const <int>[],
              info: _decodeClientInfo(pub.info),
              offset: pub.offset,
              tags: pub.tags,
            ),
        ],
      );
    } else if (reply.hasRpc()) {
      final rpc = reply.rpc;
      return SpinifyRPCResult(
        id: id,
        timestamp: now,
        data: rpc.hasData() ? rpc.data : const <int>[],
      );
    } else if (reply.hasRefresh()) {
      final refresh = reply.refresh;
      final pb.RefreshResult(:expires, :ttl) = refresh;
      final bool expBool;
      final DateTime? ttlDT;
      if (expires == true && ttl > 0) {
        expBool = true;
        ttlDT = now.add(Duration(seconds: ttl));
      } else if (expires != true) {
        expBool = false;
        ttlDT = null;
      } else {
        expBool = false;
        ttlDT = null;
        assert(false, 'Connection refresh is invalid'); // coverage:ignore-line
      }
      return SpinifyRefreshResult(
        id: id,
        timestamp: now,
        expires: expBool,
        ttl: ttlDT,
        client: refresh.client,
        version: refresh.version,
      );
    } else if (reply.hasSubRefresh()) {
      final refresh = reply.subRefresh;
      final pb.SubRefreshResult(:expires, :ttl) = refresh;
      final bool expBool;
      final DateTime? ttlDT;
      if (expires == true && ttl > 0) {
        expBool = true;
        ttlDT = now.add(Duration(seconds: ttl));
      } else if (expires != true) {
        expBool = false;
        ttlDT = null;
      } else {
        expBool = false;
        ttlDT = null;
        assert(false, 'Connection refresh is invalid'); // coverage:ignore-line
      }
      return SpinifySubRefreshResult(
        id: id,
        timestamp: now,
        expires: expBool,
        ttl: ttlDT,
      );
    } else if (reply.hasError()) {
      final error = reply.error;
      return SpinifyErrorResult(
        id: id,
        timestamp: now,
        code: error.code,
        message: error.message,
        temporary: !error.hasTemporary() || error.temporary,
      );
    } else {
      // coverage:ignore-start
      throw UnimplementedError('Unsupported reply type');
      // coverage:ignore-end
    }
  }
}
