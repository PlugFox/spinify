@internal
import 'dart:convert';

import 'package:meta/meta.dart';

import '../model/channel_push.dart';
import '../model/client_info.dart';
import '../model/command.dart';
import '../model/reply.dart';
import '../model/stream_position.dart';
import 'client.pb.dart' as pb;

/// SpinifyCommand --> Protobuf Command encoder.
final class ProtobufCommandEncoder
    extends Converter<SpinifyCommand, pb.Command> {
  /// SpinifyCommand --> List<int> encoder.
  const ProtobufCommandEncoder([this.logger]);

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
  final void Function(
    int level,
    String event,
    String message,
    Map<String, Object?> context,
  )? logger;

  @override
  pb.Command convert(SpinifyCommand input) {
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
        cmd.connect = pb.ConnectRequest(
          token: connect.token,
          data: connect.data,
          subs: switch (connect.subs) {
            Map<String, SpinifySubscribeRequest> map when map.isNotEmpty =>
              <String, pb.SubscribeRequest>{
                for (final sub in map.values)
                  sub.channel: pb.SubscribeRequest(
                    channel: sub.channel,
                    token: sub.token,
                    recover: sub.recover,
                    epoch: sub.epoch,
                    offset: sub.offset,
                    data: sub.data,
                    positioned: sub.positioned,
                    recoverable: sub.recoverable,
                    joinLeave: sub.joinLeave,
                  ),
              },
            _ => null,
          },
          name: connect.name,
          version: connect.version,
        );
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
    /* assert(() {
      print('Command > ${cmd.toProto3Json()}');
      return true;
    }()); */

    /* final buffer = pb.CodedBufferWriter();
    pb.writeToCodedBufferWriter(buffer);
    return buffer.toBuffer(); */

    /* final commandData = cmd.writeToBuffer();
    final length = commandData.lengthInBytes;
    final writer = pb.CodedBufferWriter()
      ..writeInt32NoTag(length); //..writeRawBytes(commandData);
    return writer.toBuffer() + commandData; */

    return cmd;
  }
}

/// Protobuf Reply --> SpinifyReply decoder.
final class ProtobufReplyDecoder extends Converter<pb.Reply, SpinifyReply> {
  /// List<int> --> SpinifyCommand decoder.
  const ProtobufReplyDecoder([this.logger]);

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
  final void Function(
    int level,
    String event,
    String message,
    Map<String, Object?> context,
  )? logger;

  @override
  SpinifyReply convert(pb.Reply input) {
    //final reader = pb.CodedBufferReader(input);
    //while (!reader.isAtEnd()) {
    //final reply = pb.Reply();
    //reader.readMessage(reply, pb.ExtensionRegistry.EMPTY);
    final reply = input;

    /* assert(() {
      print('Reply < ${reply.toProto3Json()}');
      return true;
    }()); */

    if (reply.hasPush()) {
      return _decodePush(reply.push);
    } else if (reply.hasId() && reply.id > 0) {
      return _decodeReply(reply);
    } else if (reply.hasError()) {
      final error = reply.error;
      return SpinifyError(
        id: reply.hasId() ? reply.id : 0,
        timestamp: DateTime.now(),
        code: error.code,
        message: error.message,
        temporary: error.temporary,
      );
    } else {
      return SpinifyServerPing(
        timestamp: DateTime.now(),
      );
    }
    //}
    //assert(reader.isAtEnd(), 'Data is not fully consumed');
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
    final channel = push.channel;
    final now = DateTime.now();
    final SpinifyChannelEvent event;
    if (push.hasPub()) {
      event = SpinifyPublication(
        timestamp: DateTime.now(),
        channel: channel,
        data: push.pub.data,
        info: _decodeClientInfo(push.pub.info),
        offset: push.pub.offset,
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
        data: push.subscribe.data,
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
        assert(false, 'Connection expires is invalid');
      }
      Duration? pingInterval;
      if (ping > 0) {
        pingInterval = Duration(seconds: ping);
      } else {
        assert(false, 'Ping interval is invalid');
      }
      event = SpinifyConnect(
        channel: channel,
        timestamp: DateTime.now(),
        client: push.connect.client,
        version: push.connect.version,
        expires: expBool,
        ttl: ttlDT,
        data: push.connect.data,
        node: push.connect.node,
        pingInterval: pingInterval,
        sendPong: push.connect.pong == true,
        session: push.connect.session,
      );
    } else if (push.hasDisconnect()) {
      event = SpinifyDisconnect(
        timestamp: DateTime.now(),
        reason: push.disconnect.reason,
        channel: channel,
        code: push.disconnect.code,
        reconnect: push.disconnect.reconnect,
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
        assert(false, 'Connection refresh is invalid');
      }
      event = SpinifyRefresh(
        timestamp: DateTime.now(),
        channel: channel,
        expires: expBool,
        ttl: ttlDT,
      );
    } else {
      throw UnimplementedError('Unsupported push type');
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
        assert(false, 'Connection expires is invalid');
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
              // TODO(plugfox): SpinifyPublication in SubscribeResult do not
              // have the "channel" field - I should fill it in manually
              // by copying the channel from the SubscribeRequest
              channel: '',
              data: pub.data,
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
        assert(false, 'Connection expires is invalid');
      }
      Duration? pingInterval;
      if (ping > 0) {
        pingInterval = Duration(seconds: ping);
      } else {
        assert(false, 'Ping interval is invalid');
      }
      return SpinifyConnectResult(
        id: id,
        timestamp: now,
        client: connect.client,
        version: connect.version,
        expires: expBool,
        ttl: ttlDT,
        data: connect.data,
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
      );
    } else if (reply.hasRpc()) {
      final rpc = reply.rpc;
      return SpinifyRPCResult(
        id: id,
        timestamp: now,
        data: rpc.data,
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
        assert(false, 'Connection refresh is invalid');
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
        assert(false, 'Connection refresh is invalid');
      }
      return SpinifySubRefreshResult(
        id: id,
        timestamp: now,
        expires: expBool,
        ttl: ttlDT,
      );
    } else {
      throw UnimplementedError('Unsupported reply type');
    }
  }
}
