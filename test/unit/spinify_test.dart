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
  group('Spinify', () {
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
        final client = createFakeClient((_) async => transport..reset());
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
        final client = createFakeClient((_) async => transport..reset());
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
      () => fakeAsync(
        (async) {
          final transport = WebSocket$Fake();
          final client = createFakeClient((_) async => transport..reset());
          unawaited(client.connect(url));
          expect(
            client.state,
            isA<SpinifyState$Connecting>().having(
              (s) => s.url,
              'url',
              equals(url),
            ),
          );
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
              milliseconds:
                  client.config.connectionRetryInterval.min.inMilliseconds ~/
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
      ),
    );

    test(
      'Rpc_requests',
      () => fakeAsync(
        (async) {
          final ws = WebSocket$Fake(); // ignore: close_sinks
          final client = createFakeClient((_) async => ws..reset())
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
          final client = createFakeClient((_) async => ws);

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
              final client = createFakeClient((_) async => ws..reset());
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
          final client = createFakeClient((_) async {
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
          final client = createFakeClient((_) async {
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
          final client = createFakeClient((_) async {
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
      return fakeAsync((async) {
        final client = createFakeClient(
          (_) async => WebSocket$Fake()
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
                      ttl: 3600,
                      data: null,
                      subs: <String, pb.SubscribeResult>{},
                      ping: 600,
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
                    },
                  );
                } else if (command.hasRefresh()) {
                  final reply = pb.RefreshResult(
                    client: 'fake',
                    version: '0.0.1',
                    expires: true,
                    ttl: 3600,
                  );
                  final bytes = ProtobufCodec.encode(reply);
                  sink.add(bytes);
                }
              });
            }
            ..onDone = () {
              pingTimer.cancel();
            },
        );

        client.connect(url);
        async.elapse(const Duration(hours: 1));
        client.close();
      });
    });
  });
}
