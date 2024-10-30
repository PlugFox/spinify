import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:spinify/spinify.dart';
import 'package:spinify/src/protobuf/client.pb.dart' as pb;
import 'package:test/test.dart';

import 'codecs.dart';
import 'web_socket_fake.dart';

//import 'server_subscription_test.mocks.dart';

//@GenerateNiceMocks([MockSpec<WebSocket>(as: #MockWebSocket)])
void main() {
  group('SpinifyServerSubscription', () {
    const url = 'ws://localhost:8000/connection/websocket';
    final buffer = SpinifyLogBuffer(size: 10);

    Spinify createFakeClient([Future<WebSocket> Function(String)? transport]) =>
        Spinify(
          config: SpinifyConfig(
            transportBuilder: ({required url, headers, protocols}) =>
                transport?.call(url) ?? Future.value(WebSocket$Fake()),
            logger: buffer.add,
          ),
        );

    test(
      'Emulate_server_subscription',
      () => fakeAsync(
        (async) {
          final client = createFakeClient(
            (_) async => WebSocket$Fake()
              ..onAdd = (bytes, sink) {
                final command = ProtobufCodec.decode(pb.Command(), bytes);
                scheduleMicrotask(() {
                  if (command.hasConnect()) {
                    sink.add(
                      ProtobufCodec.encode(
                        pb.Reply(
                          id: command.id,
                          connect: pb.ConnectResult(
                            client: 'fake',
                            version: '0.0.1',
                            expires: false,
                            ttl: null,
                            data: null,
                            subs: <String, pb.SubscribeResult>{
                              'notification:index': pb.SubscribeResult(
                                data: const <int>[],
                                epoch: '...',
                                offset: Int64.ZERO,
                                expires: false,
                                ttl: null,
                                positioned: false,
                                publications: <pb.Publication>[
                                  pb.Publication(
                                    data: const <int>[],
                                    info: pb.ClientInfo(
                                      client: 'fake',
                                      user: 'fake',
                                    ),
                                    tags: const <String, String>{
                                      'type': 'notification',
                                    },
                                  ),
                                ],
                                recoverable: false,
                                recovered: false,
                                wasRecovering: false,
                              ),
                            },
                            ping: 600,
                            pong: false,
                            session: 'fake',
                            node: 'fake',
                          ),
                        ),
                      ),
                    );
                  }
                });
              },
          );

          client.connect(url).ignore();
          async.elapse(client.config.timeout);
          expect(client.state.isConnected, isTrue);
          expect(client.subscriptions.server, isNotEmpty);
          expect(client.subscriptions.server['notification:index'], isNotNull);
          expect(
            client.getServerSubscription('notification:index'),
            same(client.subscriptions.server['notification:index']),
          );
          expect(
            client.getClientSubscription('notification:index'),
            isNull,
          );
          expect(
            client.subscriptions.client['notification:index'],
            isNull,
          );
          expect(
            client.subscriptions.server,
            isA<Map<String, SpinifyServerSubscription>>()
                .having(
                  (s) => s.length,
                  'length',
                  1,
                )
                .having(
                  (s) => s['notification:index'],
                  'notification:index',
                  isA<SpinifyServerSubscription>(),
                ),
          );

          client.close();
        },
      ),
    );
  });
}
