import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:spinify/spinify.dart';
import 'package:spinify/src/protobuf/client.pb.dart' as pb;
import 'package:test/test.dart';

import 'codecs.dart';
import 'web_socket_fake.dart';

//import 'subscription_test.mocks.dart';

//@GenerateNiceMocks([MockSpec<WebSocket>(as: #MockWebSocket)])
void main() {
  group('ServerSubscription', () {
    const url = 'ws://localhost:8000/connection/websocket';
    final buffer = SpinifyLogBuffer(size: 10);

    Spinify createFakeClient({
      Future<WebSocket> Function(String)? transport,
      Future<String?> Function()? getToken,
    }) =>
        Spinify(
          config: SpinifyConfig(
            getToken: getToken,
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
            transport: (_) async => WebSocket$Fake()
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
          )..connect(url);
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

    test(
        'Events',
        () => fakeAsync((async) {
              Timer? pingTimer, notificationTimer;
              final client = createFakeClient(
                transport: (_) async {
                  pingTimer?.cancel();
                  notificationTimer?.cancel();
                  late WebSocket$Fake ws; // ignore: close_sinks
                  return ws = WebSocket$Fake()
                    ..onAdd = (bytes, sink) {
                      final command = ProtobufCodec.decode(pb.Command(), bytes);
                      scheduleMicrotask(() {
                        if (command.hasConnect()) {
                          final reply = pb.Reply(
                            id: command.id,
                            connect: pb.ConnectResult(
                              client: 'fake',
                              version: '0.0.1',
                              expires: true,
                              ttl: 600,
                              data: null,
                              subs: <String, pb.SubscribeResult>{
                                'notification:index': pb.SubscribeResult(
                                  data: utf8.encode('notification:index'),
                                  epoch: '...',
                                  offset: Int64.ZERO,
                                  expires: false,
                                  ttl: null,
                                  positioned: false,
                                  publications: <pb.Publication>[
                                    pb.Publication(
                                      offset: Int64.ONE,
                                      data: const <int>[1, 2, 3],
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
                                'echo:index': pb.SubscribeResult(
                                  data: utf8.encode('echo:index'),
                                  epoch: '...',
                                  offset: Int64.ZERO,
                                  expires: false,
                                  ttl: null,
                                  positioned: false,
                                  publications: <pb.Publication>[],
                                  recoverable: false,
                                  recovered: false,
                                  wasRecovering: false,
                                ),
                              },
                              ping: 600,
                              pong: true,
                              session: 'fake',
                              node: 'fake',
                            ),
                          );
                          sink.add(ProtobufCodec.encode(reply));
                          pingTimer = Timer.periodic(
                            Duration(milliseconds: reply.connect.ping),
                            (timer) {
                              if (ws.isClosed) {
                                timer.cancel();
                                return;
                              }
                              sink.add(ProtobufCodec.encode(pb.Reply()));
                            },
                          );
                          notificationTimer = Timer.periodic(
                            const Duration(minutes: 5),
                            (timer) {
                              if (ws.isClosed) {
                                timer.cancel();
                                return;
                              }
                              sink.add(ProtobufCodec.encode(pb.Reply(
                                push: pb.Push(
                                  channel: 'notification:index',
                                  message: pb.Message(
                                    data: utf8.encode(DateTime.now()
                                        .toUtc()
                                        .toIso8601String()),
                                  ),
                                ),
                              )));
                            },
                          );
                        } else if (command.hasRefresh()) {
                          if (command.refresh.token.isEmpty) return;
                          final reply = pb.Reply()
                            ..id = command.id
                            ..refresh = pb.RefreshResult(
                              client: 'fake',
                              version: '0.0.1',
                              expires: true,
                              ttl: 600,
                            );
                          final bytes = ProtobufCodec.encode(reply);
                          sink.add(bytes);
                        }
                      });
                    };
                },
              )..connect(url);
              expectLater(
                client.states,
                emitsInOrder([
                  isA<SpinifyState$Connecting>(),
                  isA<SpinifyState$Connected>(),
                  isA<SpinifyState$Disconnected>(),
                  isA<SpinifyState$Closed>(),
                  emitsDone,
                ]),
              );
              async.elapse(client.config.timeout);
              expectLater(
                client.subscriptions.server['notification:index']?.stream
                    .message(),
                emitsInOrder([
                  for (var i = 0; i < 10; i++)
                    isA<SpinifyMessage>().having(
                      (m) => m.data,
                      'data',
                      isA<List<int>>().having(
                        (bytes) => DateTime.parse(utf8.decode(bytes)),
                        'DateTime.parse',
                        isA<DateTime>(),
                      ),
                    ),
                ]),
              );
              expect(client.state.isConnected, isTrue);
              async.elapse(const Duration(days: 1));
              expect(client.state.isConnected, isTrue);
              expect(client.subscriptions.server, isNotEmpty);
              pingTimer?.cancel();
              client.close();
              async.flushTimers();
              expect(client.state.isConnected, isFalse);
              expect(client.isClosed, isTrue);
            }));
  });
}
