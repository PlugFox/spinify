import 'dart:async';
import 'dart:convert';
import 'dart:js_interop' as js;
import 'dart:typed_data';

import 'package:protobuf/protobuf.dart' as pb;
import 'package:spinify/src/protobuf/client.pb.dart' as pb;
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import 'create_client.dart' as variables;

void main() => group('Transport_WS_JS', () {
      test(
        'WebSocket_JSON_RPC_Disconnect_permanent',
        () async {
          final socket = web.WebSocket(
            variables.$url,
            ['centrifuge-json'.toJS].toJS,
          );
          await socket.onOpen.first;
          final messages = StreamController<Map<String, Object?>>.broadcast();
          socket.onMessage
              .map((e) => e.data)
              .cast<String>()
              .map(jsonDecode)
              .cast<Map<String, Object?>>()
              .listen(messages.add);
          void send(String message) => socket.send(message.toJS);
          try {
            expect(socket.readyState, equals(web.WebSocket.OPEN));
            send('{"connect":{"name":"test"},"id":1}');
            await expectLater(
                messages.stream.first,
                completion(
                  allOf(
                    containsPair('id', 1),
                    containsPair('connect', isA<Map<String, Object?>>()),
                  ),
                ));
            expect(socket.readyState, equals(web.WebSocket.OPEN));
            send('{"rpc":{"method":"disconnect","data":"permanent"},"id":2}');
            await expectLater(
              messages.stream.first,
              completion(allOf(
                containsPair('id', 2),
                containsPair('rpc', isA<Map<String, Object?>>()),
              )),
            );
            expect(socket.readyState, equals(web.WebSocket.OPEN));
            await expectLater(
              socket.onClose.first,
              completion(
                isA<web.CloseEvent>()
                    .having(
                      (e) => e.code,
                      'code',
                      equals(3503),
                    )
                    .having(
                      (e) => e.reason,
                      'reason',
                      equals('force disconnect'),
                    ),
              ),
            );
            expect(socket.readyState, equals(web.WebSocket.CLOSED));
          } finally {
            messages.close().ignore();
            if (socket.readyState == web.WebSocket.OPEN) {
              socket.close(1000, 'Normal closure');
            }
          }
        },
      );

      test(
        'WebSocket_PB_RPC_Disconnect_permanent',
        () async {
          final socket = web.WebSocket(
            variables.$url,
            ['centrifuge-protobuf'.toJS].toJS,
          );
          await socket.onOpen.first;
          final onClose = StreamController<web.CloseEvent>();
          final onMessage = StreamController<pb.Reply>.broadcast();
          final events = StreamController<web.Event>()
            ..stream
                .asyncMap<void>((event) async {
                  switch (event.type) {
                    case 'close':
                      onClose.add(event as web.CloseEvent);
                    case 'message':
                      final blob = (event as web.MessageEvent).data as web.Blob;
                      final buffer = await blob.arrayBuffer().toDart;
                      final bytes = buffer.toDart.asUint8List();
                      final reader = pb.CodedBufferReader(bytes);
                      final reply = pb.Reply();
                      reader.readMessage(reply, pb.ExtensionRegistry.EMPTY);
                      onMessage.add(reply);
                    default:
                      throw UnsupportedError(
                          'Unsupported event type: ${event.type}');
                  }
                })
                .drain<void>()
                .ignore();
          socket
            ..onMessage
                .map((e) => e.data)
                .cast<web.Blob>()
                .asyncMap((b) => b.arrayBuffer().toDart)
                .map((a) => a.toDart.asUint8List())
                .map(pb.CodedBufferReader.new)
                .map((reader) {
                  final reply = pb.Reply();
                  reader.readMessage(reply, pb.ExtensionRegistry.EMPTY);
                  return reply;
                })
                .where((_) => !onMessage.isClosed)
                .listen(onMessage.add)
            ..onClose.listen(events.add);

          void send(pb.Command command) {
            final commandData = command.writeToBuffer();
            final length = commandData.lengthInBytes;
            final writer = pb.CodedBufferWriter()..writeInt32NoTag(length);
            final bytes = writer.toBuffer() + commandData;
            socket.send(Uint8List.fromList(bytes).toJS);
          }

          try {
            send(pb.Command(
              id: 1,
              connect: pb.ConnectRequest(name: 'test'),
            ));
            await expectLater(
              onMessage.stream.first,
              completion(
                isA<pb.Reply>()
                    .having((r) => r.id, 'id', equals(1))
                    .having((r) => r.hasConnect(), 'hasConnect', isTrue)
                    .having(
                        (r) => r.connect, 'connect', isA<pb.ConnectResult>()),
              ),
            );
            expect(socket.readyState, equals(web.WebSocket.OPEN));
            send(pb.Command(
              id: 2,
              rpc: pb.RPCRequest(
                method: 'disconnect',
                data: utf8.encode('permanent'),
              ),
            ));
            await expectLater(
              onMessage.stream.first,
              completion(
                isA<pb.Reply>()
                    .having((r) => r.id, 'id', equals(2))
                    .having((r) => r.hasRpc(), 'hasRpc', isTrue),
              ),
            );
            await expectLater(
              onClose.stream.first,
              completion(
                isA<web.CloseEvent>()
                    .having(
                      (e) => e.code,
                      'code',
                      equals(3503),
                    )
                    .having(
                      (e) => e.reason,
                      'reason',
                      equals('force disconnect'),
                    ),
              ),
            );
            expect(socket.readyState, equals(web.WebSocket.CLOSED));
            await Future<void>.delayed(const Duration(milliseconds: 250));
          } finally {
            onClose.close().ignore();
            onMessage.close().ignore();
            events.close().ignore();
            if (socket.readyState == web.WebSocket.OPEN) {
              socket.close(1000, 'Normal closure');
            }
          }
        },
      );
    }, onPlatform: {
      'dart-vm': const Skip('Only runs on the browser.'),
    });
