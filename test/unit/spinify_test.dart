import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:mockito/annotations.dart';
import 'package:spinify/spinify.dart';
import 'package:spinify/src/protobuf/client.pb.dart' as pb;
import 'package:test/test.dart';

import 'codecs.dart';
import 'web_socket_fake.dart';

@GenerateNiceMocks([MockSpec<WebSocket>(as: #MockWebSocket)])
void main() {
  group(
    'Spinify',
    () {
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

      test('Constructor', () {
        expect(Spinify.new, returnsNormally);
        expect(() => Spinify(config: SpinifyConfig()), returnsNormally);
      });

      test(
        'Create_and_close_client',
        () async {
          final client = createFakeClient();
          expect(client.isClosed, isFalse);
          expect(client.state, isA<SpinifyState$Disconnected>());
          await client.close();
          expect(client.state, isA<SpinifyState$Closed>());
          expect(client.isClosed, isTrue);
        },
      );

      test(
        'Connect',
        () => fakeAsync((async) {
          final client = Spinify.connect(
            url,
            config: SpinifyConfig(
              transportBuilder: ({required url, headers, protocols}) async =>
                  WebSocket$Fake(),
              logger: buffer.add,
            ),
          );
          expect(client.state, isA<SpinifyState$Connecting>());
          async.elapse(client.config.timeout);
          expect(client.state, isA<SpinifyState$Connected>());
          client.close();
        }),
      );

      test(
        'Disconnect_disconnected',
        () {
          final client = createFakeClient();
          expectLater(
            client.states,
            emitsInOrder(
              [
                isA<SpinifyState$Closed>(),
                emitsDone,
              ],
            ),
          );
          return fakeAsync((async) {
            expect(client.state.isDisconnected, isTrue);
            expect(client.state.isClosed, isFalse);
            async.elapse(client.config.timeout);
            expect(client.state.isDisconnected, isTrue);
            for (var i = 0; i < 10; i++) {
              client.disconnect();
              async.elapse(client.config.timeout);
              expect(client.state.isDisconnected, isTrue);
            }
            client.close();
            expect(client.state.isClosed, isTrue);
            client.close();
            expect(client.state.isClosed, isTrue);
          });
        },
      );

      test(
        'Create_and_close_multiple_clients',
        () async {
          final clients = List.generate(10, (_) => createFakeClient());
          expect(clients.every((client) => !client.isClosed), isTrue);
          await Future.wait(clients.map((client) => client.close()));
          expect(clients.every((client) => client.isClosed), isTrue);
        },
      );

      test(
        'Change_client_state',
        () async {
          final transport = WebSocket$Fake(); // ignore: close_sinks
          final client =
              createFakeClient(transport: (_) async => transport..reset());
          expect(transport.isClosed, isFalse);
          expect(client.state, isA<SpinifyState$Disconnected>());
          await client.connect(url);
          expect(client.state, isA<SpinifyState$Connected>());
          await client.disconnect();
          expect(
            client.state,
            isA<SpinifyState$Disconnected>().having(
              (s) => s.temporary,
              'temporary',
              isFalse,
            ),
          );
          await client.connect(url);
          expect(client.state, isA<SpinifyState$Connected>());
          await client.close();
          expect(client.state, isA<SpinifyState$Closed>());
          expect(client.isClosed, isTrue);
          expect(transport.isClosed, isTrue);
          expect(transport.closeCode, equals(1000));
        },
      );

      test(
        'Change_client_states',
        () {
          final transport = WebSocket$Fake(); // ignore: close_sinks
          final client =
              createFakeClient(transport: (_) async => transport..reset());
          Stream.fromIterable([
            () => client.connect(url),
            client.disconnect,
            () => client.connect(url),
            client.disconnect,
            client.close,
          ]).asyncMap(Future.new).drain<void>();
          expect(client.state, isA<SpinifyState$Disconnected>());
          expectLater(
              client.states,
              emitsInOrder([
                isA<SpinifyState$Connecting>(),
                isA<SpinifyState$Connected>(),
                isA<SpinifyState$Disconnected>(),
                isA<SpinifyState$Connecting>(),
                isA<SpinifyState$Connected>(),
                isA<SpinifyState$Disconnected>(),
                isA<SpinifyState$Closed>()
              ]));
        },
      );

      test(
        'Reconnect_after_disconnected_transport',
        () {
          late WebSocket$Fake transport;
          final client = createFakeClient(
              transport: (_) async => transport = WebSocket$Fake()
                ..onAdd = (bytes, sink) {
                  final command = ProtobufCodec.decode(pb.Command(), bytes);
                  scheduleMicrotask(() {
                    if (command.hasConnect()) {
                      final reply = pb.Reply(
                        id: command.id,
                        connect: pb.ConnectResult(
                          client: 'fake',
                          version: '0.0.1',
                          expires: false,
                          ttl: null,
                          data: null,
                          subs: <String, pb.SubscribeResult>{
                            'notifications:index': pb.SubscribeResult(
                                expires: false,
                                ttl: null,
                                data: <int>[
                                  0
                                ],
                                publications: [
                                  pb.Publication(
                                    info: pb.ClientInfo(
                                      user: 'fake',
                                      client: 'fake',
                                      chanInfo: [1, 2, 3],
                                      connInfo: [1, 2, 3],
                                    ),
                                    data: [1, 2, 3],
                                  )
                                ]),
                          },
                          ping: 600,
                          pong: false,
                          session: 'fake',
                          node: 'fake',
                        ),
                      );
                      final bytes = ProtobufCodec.encode(reply);
                      sink.add(bytes);
                    }
                  });
                });
          return fakeAsync(
            (async) {
              unawaited(client.connect(url));
              async.elapse(client.config.timeout);
              expect(
                client.state,
                isA<SpinifyState$Connected>().having(
                  (s) => s.url,
                  'url',
                  equals(url),
                ),
              );
              expect(transport, isNotNull);
              expect(transport, isA<WebSocket$Fake>());
              transport.close();
              async.elapse(const Duration(milliseconds: 50));
              expect(
                client.state,
                isA<SpinifyState$Disconnected>().having(
                  (s) => s.temporary,
                  'temporary',
                  isTrue,
                ),
              );
              async.elapse(Duration(
                  milliseconds: client
                          .config.connectionRetryInterval.min.inMilliseconds ~/
                      2));
              expect(
                client.state,
                isA<SpinifyState$Disconnected>().having(
                  (s) => s.temporary,
                  'temporary',
                  isTrue,
                ),
              );
              async.elapse(client.config.connectionRetryInterval.max);
              expect(
                client.state,
                isA<SpinifyState$Connected>().having(
                  (s) => s.url,
                  'url',
                  equals(url),
                ),
              );
              expectLater(
                client.states,
                emitsInOrder(
                  [
                    isA<SpinifyState$Disconnected>().having(
                      (s) => s.temporary,
                      'temporary',
                      isFalse,
                    ),
                    isA<SpinifyState$Closed>(),
                    emitsDone,
                  ],
                ),
              );
              client.close();
              async.elapse(client.config.connectionRetryInterval.max);
              expect(client.state, isA<SpinifyState$Closed>());
            },
          );
        },
      );

      test(
        'Rpc_requests',
        () => fakeAsync(
          (async) {
            final ws = WebSocket$Fake(); // ignore: close_sinks
            final client = createFakeClient(transport: (_) async => ws..reset())
              ..connect(url);
            expect(client.state, isA<SpinifyState$Connecting>());
            async.elapse(client.config.timeout);
            expect(client.state, isA<SpinifyState$Connected>());

            // Intercept the onAdd callback for echo RPC
            var fn = ws.onAdd;
            ws.onAdd = (bytes, sink) {
              final command = ProtobufCodec.decode(pb.Command(), bytes);
              if (command.hasRpc()) {
                expect(command.rpc.method, anyOf('echo', 'getCurrentYear'));
                switch (command.rpc.method) {
                  case 'echo':
                    final data = utf8.decode(command.rpc.data);
                    final reply = pb.Reply(
                      id: command.id,
                      rpc: pb.RPCResult(
                        data: utf8.encode(data),
                      ),
                    );
                    scheduleMicrotask(
                        () => sink.add(ProtobufCodec.encode(reply)));
                  default:
                    return fn(bytes, sink);
                }
              } else {
                fn(bytes, sink);
              }
            };

            // Send a request
            expect(
              client.rpc('echo', utf8.encode('Hello, World!')),
              completion(isA<List<int>>().having(
                (data) => utf8.decode(data),
                'data',
                equals('Hello, World!'),
              )),
            );
            async.elapse(client.config.timeout);
            expect(client.state, isA<SpinifyState$Connected>());

            // Send 1000 requests
            for (var i = 0; i < 1000; i++) {
              expect(
                client.rpc('echo', utf8.encode(i.toString())),
                completion(isA<List<int>>().having(
                  (data) => utf8.decode(data),
                  'data',
                  equals(i.toString()),
                )),
              );
            }

            async.elapse(client.config.timeout);
            expect(client.state, isA<SpinifyState$Connected>());
            client.disconnect();
            async.elapse(client.config.timeout);
            expect(client.state, isA<SpinifyState$Disconnected>());
            client.connect(url);
            async.elapse(client.config.timeout);
            expect(client.state, isA<SpinifyState$Connected>());

            // Intercept the onAdd callback for getCurrentYear RPC
            ws.onAdd = (bytes, sink) {
              final command = ProtobufCodec.decode(pb.Command(), bytes);
              if (command.hasRpc()) {
                expect(command.rpc.method, anyOf('echo', 'getCurrentYear'));
                switch (command.rpc.method) {
                  case 'getCurrentYear':
                    final reply = pb.Reply(
                      id: command.id,
                      rpc: pb.RPCResult(
                        data: utf8
                            .encode(jsonEncode({'year': DateTime.now().year})),
                      ),
                    );
                    scheduleMicrotask(
                        () => sink.add(ProtobufCodec.encode(reply)));
                  default:
                    return fn(bytes, sink);
                }
              } else {
                fn(bytes, sink);
              }
            };

            // Another request
            expect(
              client.rpc('getCurrentYear', <int>[]),
              completion(isA<List<int>>().having(
                (data) => jsonDecode(utf8.decode(data))['year'],
                'year',
                DateTime.now().year,
              )),
            );
            async.elapse(client.config.timeout);

            expect(client.state, isA<SpinifyState$Connected>());
            client.close();
            async.elapse(client.config.timeout);
            expect(client.state, isA<SpinifyState$Closed>());
          },
        ),
      );

      test(
        'Server_subscriptions',
        () => fakeAsync(
          (async) {
            final ws = WebSocket$Fake(); // ignore: close_sinks
            final client = createFakeClient(transport: (_) async => ws);

            ws.onAdd = (bytes, sink) {
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
                            'public:chat': pb.SubscribeResult(
                              expires: false,
                              ttl: null,
                              data: [],
                            ),
                            'personal:user#42': pb.SubscribeResult(
                              expires: false,
                              ttl: null,
                              data: [],
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
            };

            client.connect(url);
            async.elapse(client.config.timeout);
            expect(client.state, isA<SpinifyState$Connected>());
            expect(client.subscriptions.server, hasLength(2));
            expect(client.getServerSubscription('public:chat'), isNotNull);
            expect(client.getServerSubscription('personal:user#42'), isNotNull);
            expect(client.getSubscription('public:chat'), isNotNull);
            expect(client.getSubscription('personal:user#42'), isNotNull);
            expect(client.getServerSubscription('unknown'), isNull);
            expect(client.getSubscription('unknown'), isNull);
            client.close();
          },
        ),
      );

      test(
          'Metrics',
          () => fakeAsync((async) {
                final ws = WebSocket$Fake(); // ignore: close_sinks
                final client =
                    createFakeClient(transport: (_) async => ws..reset());
                expect(() => client.metrics, returnsNormally);
                expect(
                    client.metrics,
                    allOf([
                      isA<SpinifyMetrics>().having(
                        (m) => m.state.isConnected,
                        'isConnected',
                        isFalse,
                      ),
                      isA<SpinifyMetrics>().having(
                        (m) => m.state,
                        'state',
                        equals(client.state),
                      ),
                      isA<SpinifyMetrics>().having(
                        (m) => m.connects,
                        'connects',
                        0,
                      ),
                      isA<SpinifyMetrics>().having(
                        (m) => m.disconnects,
                        'disconnects',
                        0,
                      ),
                      isA<SpinifyMetrics>().having(
                        (m) => m.chunksReceived,
                        'messagesReceived',
                        equals(Int64.ZERO),
                      ),
                      isA<SpinifyMetrics>().having(
                        (m) => m.chunksSent,
                        'chunksSent',
                        equals(Int64.ZERO),
                      ),
                    ]));
                client.connect(url);
                async.elapse(client.config.timeout);
                expect(
                    client.metrics,
                    allOf([
                      isA<SpinifyMetrics>().having(
                        (m) => m.state.isConnected,
                        'isConnected',
                        isTrue,
                      ),
                      isA<SpinifyMetrics>().having(
                        (m) => m.state,
                        'state',
                        equals(client.state),
                      ),
                      isA<SpinifyMetrics>().having(
                        (m) => m.connects,
                        'connects',
                        1,
                      ),
                      isA<SpinifyMetrics>().having(
                        (m) => m.disconnects,
                        'disconnects',
                        0,
                      ),
                      isA<SpinifyMetrics>().having(
                        (m) => m.chunksReceived,
                        'messagesReceived',
                        greaterThan(Int64.ZERO),
                      ),
                      isA<SpinifyMetrics>().having(
                        (m) => m.chunksSent,
                        'chunksSent',
                        greaterThan(Int64.ZERO),
                      ),
                    ]));
                /* client
                ..newSubscription('channel')
                ..close();
              async.elapse(client.config.timeout);
              expect(
                  client.metrics,
                  allOf([
                    isA<SpinifyMetrics>().having(
                      (m) => m.state.isConnected,
                      'isConnected',
                      isFalse,
                    ),
                    isA<SpinifyMetrics>().having(
                      (m) => m.state,
                      'state',
                      equals(client.state),
                    ),
                    isA<SpinifyMetrics>().having(
                      (m) => m.connects,
                      'connects',
                      1,
                    ),
                    isA<SpinifyMetrics>().having(
                      (m) => m.disconnects,
                      'disconnects',
                      1,
                    ),
                  ]));
              expect(() => client.metrics.toString(), returnsNormally);
              expect(client.metrics.toString(), equals('SpinifyMetrics{}'));
              expect(() => client.metrics.toJson(), returnsNormally);
              expect(client.metrics.toJson(), isA<Map<String, Object?>>());
              expect(client.metrics.channels, hasLength(2));
              expect(
                  client.metrics.channels['channel'],
                  isA<SpinifyMetrics$Channel>().having((c) => c.toString(),
                      'subscriptions', equals(r'SpinifyMetrics$Channel{}'))); */
              }));

      test(
        'Ping_pong',
        () => fakeAsync(
          (async) {
            var serverPingCount = 0;
            var serverPongCount = 0;
            final client = createFakeClient(transport: (_) async {
              Timer? pingTimer;
              return WebSocket$Fake()
                ..onAdd = (bytes, sink) {
                  final command = ProtobufCodec.decode(pb.Command(), bytes);
                  if (command.hasConnect()) {
                    final reply = pb.Reply(
                      id: command.id,
                      connect: pb.ConnectResult(
                        client: 'fake',
                        version: '0.0.1',
                        expires: false,
                        ttl: null,
                        data: null,
                        subs: <String, pb.SubscribeResult>{},
                        ping: 600,
                        pong: true,
                        session: 'fake',
                        node: 'fake',
                      ),
                    );
                    scheduleMicrotask(() {
                      sink.add(ProtobufCodec.encode(reply));
                      pingTimer = Timer.periodic(
                        Duration(milliseconds: reply.connect.ping),
                        (_) {
                          serverPingCount++;
                          sink.add(ProtobufCodec.encode(pb.Reply()));
                        },
                      );
                    });
                  } else if (command.hasPing()) {
                    serverPongCount++;
                  }
                }
                ..onDone = () {
                  pingTimer?.cancel();
                };
            });
            unawaited(client.connect(url));
            async.elapse(client.config.timeout);
            expect(client.state, isA<SpinifyState$Connected>());
            async.elapse(client.config.serverPingDelay * 10);
            expect(serverPingCount, greaterThan(0));
            expect(serverPongCount, equals(serverPingCount));
            client.close();
          },
        ),
      );

      test(
        'Ping_without_pong',
        () => fakeAsync(
          (async) {
            var serverPingCount = 0, serverPongCount = 0;
            final client = createFakeClient(transport: (_) async {
              Timer? pingTimer;
              return WebSocket$Fake()
                ..onAdd = (bytes, sink) {
                  final command = ProtobufCodec.decode(pb.Command(), bytes);
                  if (command.hasConnect()) {
                    final reply = pb.Reply(
                      id: command.id,
                      connect: pb.ConnectResult(
                        client: 'fake',
                        version: '0.0.1',
                        expires: false,
                        ttl: null,
                        data: null,
                        subs: <String, pb.SubscribeResult>{},
                        ping: 600,
                        pong: false,
                        session: 'fake',
                        node: 'fake',
                      ),
                    );
                    scheduleMicrotask(() {
                      sink.add(ProtobufCodec.encode(reply));
                      pingTimer = Timer.periodic(
                        Duration(milliseconds: reply.connect.ping),
                        (_) {
                          serverPingCount++;
                          sink.add(ProtobufCodec.encode(pb.Reply()));
                        },
                      );
                    });
                  } else if (command.hasPing()) {
                    serverPongCount++;
                  }
                }
                ..onDone = () {
                  pingTimer?.cancel();
                };
            });
            unawaited(client.connect(url));
            async.elapse(client.config.timeout);
            expect(client.state, isA<SpinifyState$Connected>());
            async.elapse(client.config.serverPingDelay * 10);
            expect(serverPingCount, greaterThan(0));
            expect(serverPongCount, isZero);
            client.close();
          },
        ),
      );

      test(
        'Missing_pings',
        () => fakeAsync(
          (async) {
            final webSockets = <WebSocket$Fake>[];
            var serverPingCount = 0, serverPongCount = 0;
            final client = createFakeClient(transport: (_) async {
              final ws = WebSocket$Fake()
                ..onAdd = (bytes, sink) {
                  final command = ProtobufCodec.decode(pb.Command(), bytes);
                  if (command.hasConnect()) {
                    final reply = pb.Reply(
                      id: command.id,
                      connect: pb.ConnectResult(
                        client: 'fake',
                        version: '0.0.1',
                        expires: false,
                        ttl: null,
                        data: null,
                        subs: <String, pb.SubscribeResult>{},
                        ping: 600,
                        pong: true,
                        session: 'fake',
                        node: 'fake',
                      ),
                    );
                    scheduleMicrotask(() {
                      sink.add(ProtobufCodec.encode(reply));
                    });
                  } else if (command.hasPing()) {
                    serverPongCount++;
                  }
                }
                ..onDone = () {};
              webSockets.add(ws);
              return ws;
            });
            expectLater(
              client.states,
              emitsInOrder(
                [
                  isA<SpinifyState$Connecting>(),
                  isA<SpinifyState$Connected>(),
                  isA<SpinifyState$Disconnected>(),
                  isA<SpinifyState$Connecting>(),
                  isA<SpinifyState$Connected>(),
                  isA<SpinifyState$Disconnected>(),
                  isA<SpinifyState$Connecting>(),
                  isA<SpinifyState$Connected>(),
                  isA<SpinifyState$Disconnected>(),
                  isA<SpinifyState$Connecting>(),
                  isA<SpinifyState$Connected>(),
                  isA<SpinifyState$Disconnected>(),
                ],
              ),
            );
            unawaited(client.connect(url));
            async.elapse(client.config.timeout);
            expect(client.state, isA<SpinifyState$Connected>());
            final pingInterval =
                (client.state as SpinifyState$Connected).pingInterval!;
            async.elapse(
              (pingInterval +
                      client.config.timeout +
                      client.config.serverPingDelay) *
                  10,
            );
            expect(webSockets.length, greaterThan(1));
            expect(serverPingCount, isZero);
            expect(serverPongCount, isZero);
            client.close();
            async.elapse(const Duration(seconds: 1));
            expect(webSockets.every((ws) => ws.isClosed), isTrue);
          },
        ),
      );

      test(
        'ready',
        () => fakeAsync((async) {
          final client = createFakeClient();
          expectLater(client.ready(), completes);
          client.connect(url);
          //expectLater(client.ready(), completes);
          async.elapse(client.config.timeout);
          expect(client.state, isA<SpinifyState$Connected>());
          expectLater(client.ready(), completes);
          async.elapse(client.config.timeout);
          client.close();
        }),
      );

      test('do_not_ready', () {
        final client = createFakeClient();
        expectLater(
          client.ready(),
          throwsA(isA<SpinifyConnectionException>()),
        );
        expectLater(
          client.send([1, 2, 3]),
          throwsA(isA<SpinifySendException>()),
        );
        expectLater(
          client.rpc('echo', [1, 2, 3]),
          throwsA(isA<SpinifyRPCException>()),
        );
        client.close();
      });

      test('subscribtion_asserts', () {
        final client = createFakeClient();
        expect(
          () => client.newSubscription(''),
          throwsA(isA<AssertionError>()),
        );
        expect(
          () => client.newSubscription(' '),
          throwsA(isA<AssertionError>()),
        );
        expect(
          () => client.newSubscription(String.fromCharCode(0x7f + 1)),
          throwsA(isA<AssertionError>()),
        );
        expect(
          () => client.newSubscription('😀, 🌍, 🎉, 👋'),
          throwsA(isA<AssertionError>()),
        );
        expect(
          () => client.newSubscription('channel' * 100),
          throwsA(isA<AssertionError>()),
        );
        expect(
          () => client.newSubscription('channel'),
          returnsNormally,
        );
        expect(
          () => client.newSubscription('channel'),
          throwsA(isA<SpinifySubscriptionException>()),
        );
        client.close();
      });

      test('Auto_refresh', () {
        late Timer pingTimer;
        var pings = 0, refreshes = 0;
        final client = createFakeClient(
          getToken: () async => 'token',
          transport: (_) async => WebSocket$Fake()
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
                      subs: <String, pb.SubscribeResult>{},
                      ping: 120,
                      pong: true,
                      session: 'fake',
                      node: 'fake',
                    ),
                  );
                  final bytes = ProtobufCodec.encode(reply);
                  sink.add(bytes);
                  pingTimer = Timer.periodic(
                    Duration(milliseconds: reply.connect.ping),
                    (_) {
                      sink.add(ProtobufCodec.encode(pb.Reply()));
                      pings++;
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
                  refreshes++;
                }
              });
            }
            ..onDone = () {
              pingTimer.cancel();
            },
        );
        return fakeAsync((async) {
          client.connect(url);
          async.elapse(const Duration(hours: 3));
          expect(client.state.isConnected, isTrue);
          expect(client.isClosed, isFalse);
          client.close();
          expect(client.state.isClosed, isTrue);
          expect(pings, greaterThanOrEqualTo(3 * 60 * 60 ~/ 120));
          expect(refreshes, greaterThanOrEqualTo(3 * 60 * 60 ~/ 600));
        });
      });

      test('Error_future', () {
        final fakeException = Exception('Fake error');
        expect(fakeException, isA<Exception>());
        Future<void>.error(fakeException).ignore();
        unawaited(
          expectLater(
            Future<void>.error(fakeException),
            throwsA(isA<Exception>()),
          ),
        );
        unawaited(
          expectLater(
            Future<void>.delayed(const Duration(milliseconds: 5), () {
              throw fakeException;
            }),
            throwsA(isA<Exception>()),
          ),
        );
      });

      test(
        'Disconnect_during_connection',
        () async {
          try {
            final client = createFakeClient();
            unawaited(
              expectLater(
                client.connect(url).onError((error, stackTrace) {
                  Error.throwWithStackTrace(error!, stackTrace);
                }),
                throwsA(anything),
              ),
            );
            await client.disconnect();
            expect(client.state.isDisconnected, isTrue);
            expect(client.state.isClosed, isFalse);
            await client.close();
            expect(client.state.isClosed, isTrue);
          } on Object {
            print('Wat?');
          }
        },
        skip: true,
      );

      // Retry connection after temporary error
      /* test(
        'Connection_error_retry',
        () => fakeAsync(
          (async) {
            late Timer pingTimer;
            var pings = 0, retries = 0;
            late final client = createFakeClient(
              getToken: () async => 'token',
              transport: (_) async {
                late WebSocket$Fake ws;
                return ws = WebSocket$Fake()
                  ..onAdd = (bytes, sink) {
                    final command = ProtobufCodec.decode(pb.Command(), bytes);
                    scheduleMicrotask(() {
                      if (command.hasConnect()) {
                        if (retries < 2) {
                          final reply = pb.Reply(
                            id: command.id,
                            error: pb.Error(
                              code: 3000,
                              message: 'Fake connection error',
                              temporary: true,
                            ),
                          );
                          final bytes = ProtobufCodec.encode(reply);
                          sink.add(bytes);
                          retries++;
                        } else {
                          final reply = pb.Reply(
                            id: command.id,
                            connect: pb.ConnectResult(
                              client: 'fake',
                              version: '0.0.1',
                              expires: true,
                              ttl: 600,
                              data: null,
                              subs: <String, pb.SubscribeResult>{},
                              ping: 120,
                              pong: false,
                              session: 'fake',
                              node: 'fake',
                            ),
                          );
                          final bytes = ProtobufCodec.encode(reply);
                          sink.add(bytes);
                          pingTimer = Timer.periodic(
                            Duration(milliseconds: reply.connect.ping),
                            (timer) {
                              if (ws.isClosed) {
                                timer.cancel();
                              } else {
                                sink.add(ProtobufCodec.encode(pb.Reply()));
                                pings++;
                              }
                            },
                          );
                        }
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
                  }
                  ..onDone = () {
                    pingTimer.cancel();
                  };
              },
            );
            expectLater(
              client.connect(url),
              throwsA(isA<SpinifyException>()),
            );
            //client.states.forEach((s) => print(' *** State: $s'));
            async.elapse(client.config.timeout);
            expect(
              client.state,
              isA<SpinifyState$Disconnected>().having(
                (s) => s.temporary,
                'temporary',
                isTrue,
            ));
            //async.elapse(const Duration(hours: 3));
            expect(client.state.isConnected, isTrue);
            expect(client.isClosed, isFalse);
            client.close();
            async.elapse(const Duration(minutes: 1));
            expect(client.state.isClosed, isTrue);
            expect(pings, greaterThanOrEqualTo(1));
            expect(retries, equals(2));
          },
        ),
        skip: true,
      ); */
    },
  );
}
