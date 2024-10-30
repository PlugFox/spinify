import 'package:protobuf/protobuf.dart' as pb;
import 'package:spinify/spinify.dart';
import 'package:spinify/src/protobuf/client.pb.dart' as pb;
import 'package:test/test.dart';

void main() => group('Codec', () {
      test('Command_encoding', () {
        final command = SpinifySendRequest(
          timestamp: DateTime(2021, 1, 1),
          data: [for (var i = 0; i < 256; i++) i],
        );
        const codec = SpinifyProtobufCommandEncoder();
        final bytesFromCodec = codec.convert(command);
        expect(bytesFromCodec.length, greaterThan(0));

        // Try read the bytes back.
        final reader = pb.CodedBufferReader(bytesFromCodec);
        final decoded = pb.Command();
        reader.readMessage(decoded, pb.ExtensionRegistry.EMPTY);

        expect(reader.isAtEnd(), isTrue);
        expect(decoded.id, equals(command.id));
        expect(decoded.send.data, equals(command.data));

        // Compare with direct encoding through protobuf and concatenation.
        final commandData = decoded.writeToBuffer();
        final writer = pb.CodedBufferWriter()
          ..writeInt32NoTag(commandData.lengthInBytes);
        final bytesFromTest = writer.toBuffer() + commandData;
        expect(bytesFromCodec.length, equals(bytesFromTest.length));
        expect(bytesFromCodec, equals(bytesFromTest));
      });

      test('Protobuf_commands', () {
        final commands = <SpinifyCommand>[
          SpinifyConnectRequest(
            id: 1,
            timestamp: DateTime(2021, 1, 1),
            token: 'token',
            data: const [1, 2, 3],
            name: 'name',
            version: '1.2.3',
            subs: {
              'channel': SpinifySubscribeRequest(
                id: 2,
                timestamp: DateTime(2021, 1, 1),
                channel: 'channel',
                data: const [4, 5, 6],
                epoch: 'epoch',
                joinLeave: true,
                offset: Int64.ZERO,
                positioned: true,
                recover: true,
                recoverable: true,
                token: 'token',
              ),
            },
          ),
          SpinifySubscribeRequest(
            channel: 'channel',
            data: const [1, 2, 3],
            epoch: 'epoch',
            id: 1,
            joinLeave: true,
            offset: Int64.ZERO,
            positioned: true,
            recover: true,
            recoverable: true,
            timestamp: DateTime(2021, 1, 1),
            token: 'token',
          ),
          SpinifyUnsubscribeRequest(
            channel: 'channel',
            id: 1,
            timestamp: DateTime(2021, 1, 1),
          ),
          SpinifyPublishRequest(
            channel: 'channel',
            data: const [1, 2, 3],
            id: 1,
            timestamp: DateTime(2021, 1, 1),
          ),
          SpinifyPresenceRequest(
            channel: 'channel',
            id: 1,
            timestamp: DateTime(2021, 1, 1),
          ),
          SpinifyPresenceStatsRequest(
            channel: 'channel',
            id: 1,
            timestamp: DateTime(2021, 1, 1),
          ),
          SpinifyHistoryRequest(
            channel: 'channel',
            id: 1,
            limit: 1,
            since: (epoch: 'epoch', offset: Int64.ZERO),
            timestamp: DateTime(2021, 1, 1),
            reverse: false,
          ),
          SpinifyPingRequest(timestamp: DateTime(2021, 1, 1)),
          SpinifySendRequest(
            data: const [1, 2, 3],
            timestamp: DateTime(2021, 1, 1),
          ),
          SpinifyRPCRequest(
            data: const [1, 2, 3],
            id: 1,
            method: 'method',
            timestamp: DateTime(2021, 1, 1),
          ),
          SpinifyRefreshRequest(
            id: 1,
            timestamp: DateTime(2021, 1, 1),
            token: 'token',
          ),
          SpinifySubRefreshRequest(
            id: 1,
            timestamp: DateTime(2021, 1, 1),
            token: 'token',
            channel: 'channel',
          ),
        ];
        final codec = SpinifyProtobufCodec();
        for (final command in commands) {
          expect(
            codec.encoder.convert(command),
            allOf(
              isNotEmpty,
              isA<List<int>>(),
            ),
          );
        }
      });

      test('Protobuf_replies', () {
        final replies = <pb.Reply>[
          pb.Reply(),
          pb.Reply()
            ..id = 1
            ..error = pb.Error()
            ..error.message = 'message'
            ..error.code = 1
            ..error.temporary = true,
          pb.Reply()
            ..id = 1
            ..connect = pb.ConnectResult()
            ..connect.expires = true
            ..connect.ttl = 1
            ..connect.version = 'version'
            ..connect.client = 'client'
            ..connect.data = [1, 2, 3]
            ..connect.node = 'node'
            ..connect.ping = 600
            ..connect.pong = true
            ..connect.session = 'session'
            ..connect.subs.addAll(<String, pb.SubscribeResult>{
              'channel': pb.SubscribeResult()
                ..expires = true
                ..ttl = 1
                ..recoverable = true
                ..epoch = 'epoch'
            }),
          pb.Reply()
            ..id = 1
            ..subscribe = pb.SubscribeResult()
            ..subscribe.expires = true
            ..subscribe.ttl = 1
            ..subscribe.recoverable = true
            ..subscribe.epoch = 'epoch'
            ..subscribe.recovered = true
            ..subscribe.data = [1, 2, 3]
            ..subscribe.positioned = true
            ..subscribe.wasRecovering = true,
          pb.Reply()
            ..id = 1
            ..unsubscribe = pb.UnsubscribeResult(),
          pb.Reply()
            ..id = 1
            ..publish = pb.PublishResult(),
          pb.Reply()
            ..id = 1
            ..presence = pb.PresenceResult()
            ..presence.presence.addAll(<String, pb.ClientInfo>{
              'client': pb.ClientInfo()
                ..client = 'client'
                ..user = 'user'
                ..chanInfo = [1, 2, 3]
            }),
          pb.Reply()
            ..id = 1
            ..presenceStats = pb.PresenceStatsResult()
            ..presenceStats.numClients = 1
            ..presenceStats.numUsers = 1,
          pb.Reply()
            ..id = 1
            ..history = pb.HistoryResult()
            ..history.epoch = 'epoch'
            ..history.offset = Int64.ZERO
            ..history.publications.addAll(<pb.Publication>{
              pb.Publication()
                ..data = [1, 2, 3]
                ..info = pb.ClientInfo()
                ..info.client = 'client'
                ..info.user = 'user'
                ..info.chanInfo = [1, 2, 3]
            }),
          pb.Reply()
            ..id = 1
            ..rpc = pb.RPCResult()
            ..rpc.data = [1, 2, 3],
          pb.Reply()
            ..id = 1
            ..refresh = pb.RefreshResult()
            ..refresh.expires = true
            ..refresh.ttl = 1
            ..refresh.client = 'client'
            ..refresh.version = 'version',
          pb.Reply()
            ..id = 1
            ..subRefresh = pb.SubRefreshResult()
            ..subRefresh.expires = true
            ..subRefresh.ttl = 1,
          pb.Reply()
            ..push = pb.Push()
            ..push.pub = pb.Publication()
            ..push.pub.data = [1, 2, 3]
            ..push.pub.offset = Int64.ZERO
            ..push.pub.tags.addAll(<String, String>{'tag': 'tag'})
            ..push.pub.info = pb.ClientInfo()
            ..push.pub.info.client = 'client'
            ..push.pub.info.user = 'user'
            ..push.pub.info.chanInfo = [1, 2, 3],
          pb.Reply()
            ..push = pb.Push()
            ..push.join = pb.Join()
            ..push.join.info = pb.ClientInfo()
            ..push.join.info.client = 'client'
            ..push.join.info.user = 'user'
            ..push.join.info.chanInfo = [1, 2, 3],
          pb.Reply()
            ..push = pb.Push()
            ..push.leave = pb.Leave()
            ..push.leave.info = pb.ClientInfo(),
          pb.Reply()
            ..push = pb.Push()
            ..push.unsubscribe = pb.Unsubscribe()
            ..push.unsubscribe.code = 1
            ..push.unsubscribe.reason = 'reason',
          pb.Reply()
            ..push = pb.Push()
            ..push.message = pb.Message()
            ..push.message.data = [1, 2, 3],
          pb.Reply()
            ..push = pb.Push()
            ..push.subscribe = pb.Subscribe()
            ..push.subscribe.recoverable = true
            ..push.subscribe.epoch = 'epoch'
            ..push.subscribe.data = [1, 2, 3]
            ..push.subscribe.positioned = true,
          pb.Reply()
            ..push = pb.Push()
            ..push.connect = pb.Connect()
            ..push.connect.expires = true
            ..push.connect.ttl = 1
            ..push.connect.version = 'version'
            ..push.connect.client = 'client'
            ..push.connect.data = [1, 2, 3]
            ..push.connect.node = 'node'
            ..push.connect.ping = 600
            ..push.connect.pong = true
            ..push.connect.session = 'session'
            ..push.connect.subs.addAll(<String, pb.SubscribeResult>{
              'channel': pb.SubscribeResult()
                ..expires = true
                ..ttl = 1
                ..recoverable = true
                ..epoch = 'epoch'
            }),
          pb.Reply()
            ..push = pb.Push()
            ..push.disconnect = pb.Disconnect()
            ..push.disconnect.code = 1
            ..push.disconnect.reason = 'reason',
          pb.Reply()
            ..push = pb.Push()
            ..push.refresh = pb.Refresh()
            ..push.refresh.expires = true
            ..push.refresh.ttl = 1,
        ];
        final codec = SpinifyProtobufCodec();
        for (final reply in replies) {
          final replyData = reply.writeToBuffer();
          final writer = pb.CodedBufferWriter()
            ..writeInt32NoTag(replyData.lengthInBytes)
            ..writeRawBytes(replyData);
          final bytes = writer.toBuffer();
          expect(
            codec.decoder.convert(bytes).single,
            isA<SpinifyReply>(),
          );
        }
      });

      test('Unknown_replies', () {
        final codec = SpinifyProtobufCodec();
        expect(
          codec.decoder.convert([]),
          isEmpty,
        );
        final replyData = (pb.Reply()..push = pb.Push()).writeToBuffer();
        final writer = pb.CodedBufferWriter()
          ..writeInt32NoTag(replyData.lengthInBytes)
          ..writeRawBytes(replyData);
        final bytes = writer.toBuffer();
        expect(
          codec.decoder.convert(bytes),
          isEmpty,
        );
      });
    });
