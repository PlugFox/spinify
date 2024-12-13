import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:fake_async/fake_async.dart';
import 'package:spinify/spinify.dart';
import 'package:spinify/src/protobuf/client.pb.dart' as pb;
import 'package:test/test.dart';

import 'codecs.dart';
import 'web_socket_fake.dart';

//import 'subscription_test.mocks.dart';

//@GenerateNiceMocks([MockSpec<WebSocket>(as: #MockWebSocket)])
void main() {
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

  group('ServerSubscription', () {
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
                  var offset = Int64.ZERO;
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
                                  offset: offset,
                                  expires: false,
                                  ttl: null,
                                  positioned: false,
                                  publications: [],
                                  recoverable: false,
                                  recovered: false,
                                  wasRecovering: false,
                                ),
                                'echo:index': pb.SubscribeResult(
                                  data: utf8.encode('echo:index'),
                                  epoch: '...',
                                  offset: offset,
                                  expires: false,
                                  ttl: null,
                                  positioned: false,
                                  publications: <pb.Publication>[
                                    pb.Publication(
                                      offset: offset,
                                      data: const <int>[1, 2, 3],
                                      info: pb.ClientInfo(
                                        client: 'fake',
                                        user: 'fake',
                                      ),
                                      tags: const <String, String>{
                                        'type': 'echo',
                                      },
                                    ),
                                  ],
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
                        } else if (command.hasPublish() &&
                            command.publish.channel == 'echo:index') {
                          offset++;
                          final reply = pb.Reply()
                            ..id = command.id
                            ..publish = pb.PublishResult();
                          final bytes = ProtobufCodec.encode(reply);
                          sink
                            ..add(bytes)
                            ..add(
                              ProtobufCodec.encode(
                                pb.Reply(
                                  push: pb.Push(
                                    channel: 'echo:index',
                                    pub: pb.Publication(
                                      offset: offset,
                                      tags: const <String, String>{},
                                      data: command.publish.data,
                                      info: pb.ClientInfo(
                                        client: 'fake',
                                        chanInfo: [1, 2, 3],
                                        connInfo: [4, 5, 6],
                                        user: 'fake',
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
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
              expect(client.state.isConnected, isTrue);
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
              final echoEvents = <SpinifyChannelEvent>[];
              client.subscriptions.server['echo:index']?.stream
                  .forEach(echoEvents.add);
              for (var i = 0; i < 10; i++) {
                async.elapse(const Duration(minutes: 5));
                client.publish('echo:index', utf8.encode(i.toString()));
              }
              async.elapse(const Duration(days: 1));
              expect(client.state.isConnected, isTrue);
              expect(client.subscriptions.server, isNotEmpty);
              pingTimer?.cancel();
              client.close();
              async.elapse(client.config.timeout);
              expect(
                echoEvents,
                equals([
                  for (var i = 0; i < 10; i++)
                    isA<SpinifyPublication>()
                        .having(
                          (m) => m.data,
                          'data',
                          equals(utf8.encode(i.toString())),
                        )
                        .having(
                          (m) => m.offset,
                          'offset',
                          equals(Int64(i + 1)),
                        ),
                ]),
              );
              expect(client.state.isConnected, isFalse);
              expect(client.isClosed, isTrue);
            }));
  });

  group('ClientSubscription', () {
    test(
      'Emulate_client_subscription',
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
                            subs: <String, pb.SubscribeResult>{},
                            ping: 600,
                            pong: false,
                            session: 'fake',
                            node: 'fake',
                          ),
                        ),
                      ),
                    );
                  } else if (command.hasSubscribe()) {
                    final reply = pb.Reply(
                      id: command.id,
                      subscribe: pb.SubscribeResult(
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
                    );
                    sink.add(ProtobufCodec.encode(reply));
                  } else if (command.hasUnsubscribe()) {
                    final reply = pb.Reply(
                      id: command.id,
                      unsubscribe: pb.UnsubscribeResult(),
                    );
                    sink.add(ProtobufCodec.encode(reply));
                  } else {
                    debugger();
                  }
                });
              },
          )..connect(url);
          async.elapse(client.config.timeout);
          expect(client.state.isConnected, isTrue);
          expect(client.subscriptions.server, isEmpty);
          expect(client.subscriptions.client, isEmpty);
          final notifications = client.newSubscription('notification:index');
          expect(
            client.subscriptions.client['notification:index'],
            allOf(
              isNotNull,
              isA<SpinifyClientSubscription>()
                  .having(
                    (s) => s.channel,
                    'channel',
                    'notification:index',
                  )
                  .having(
                    (s) => s.state,
                    'state',
                    isA<SpinifySubscriptionState$Unsubscribed>(),
                  ),
            ),
          );
          notifications.subscribe();
          async.elapse(client.config.timeout);
          expect(
            client.subscriptions.client['notification:index'],
            allOf(
              isNotNull,
              isA<SpinifyClientSubscription>().having(
                (s) => s.state,
                'state',
                isA<SpinifySubscriptionState$Subscribed>(),
              ),
            ),
          );
          expect(
            client.getClientSubscription('notification:index'),
            allOf(
              isA<SpinifyClientSubscription>(),
              same(notifications),
              same(client.subscriptions.client['notification:index']),
            ),
          );
          expect(
            client.getServerSubscription('notification:index'),
            isNull,
          );
          expect(
            client.subscriptions.client,
            isA<Map<String, SpinifyClientSubscription>>()
                .having(
                  (s) => s.length,
                  'length',
                  1,
                )
                .having(
                  (s) => s['notification:index'],
                  'notification:index',
                  isA<SpinifyClientSubscription>(),
                ),
          );
          client.disconnect();
          async.elapse(client.config.timeout);
          expect(client.state.isConnected, isFalse);
          expect(client.isClosed, isFalse);
          expect(notifications.state.isUnsubscribed, isTrue);
          client.close();
          async.elapse(client.config.timeout);
          expect(client.state.isConnected, isFalse);
          expect(client.isClosed, isTrue);
        },
      ),
    );

    test(
      'Events',
      () => fakeAsync(
        (async) {
          Timer? pingTimer, notificationTimer;
          final client = createFakeClient(
            transport: (_) async {
              pingTimer?.cancel();
              notificationTimer?.cancel();
              var echo = false;
              var offset = Int64.ZERO;
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
                          subs: <String, pb.SubscribeResult>{},
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
                    } else if (command.hasPublish() &&
                        command.publish.channel == 'echo:index' &&
                        echo) {
                      offset++;
                      final reply = pb.Reply()
                        ..id = command.id
                        ..publish = pb.PublishResult();
                      final bytes = ProtobufCodec.encode(reply);
                      sink
                        ..add(bytes)
                        ..add(
                          ProtobufCodec.encode(
                            pb.Reply(
                              push: pb.Push(
                                channel: 'echo:index',
                                pub: pb.Publication(
                                  offset: offset,
                                  tags: const <String, String>{},
                                  data: command.publish.data,
                                  info: pb.ClientInfo(
                                    client: 'fake',
                                    chanInfo: [1, 2, 3],
                                    connInfo: [4, 5, 6],
                                    user: 'fake',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                    } else if (command.hasSubscribe() &&
                        command.subscribe.channel == 'notification:index') {
                      final reply = pb.Reply(
                        id: command.id,
                        subscribe: pb.SubscribeResult(
                          data: utf8.encode('notification:index'),
                          epoch: '...',
                          offset: offset,
                          expires: false,
                          ttl: null,
                          positioned: false,
                          publications: [],
                          recoverable: false,
                          recovered: false,
                          wasRecovering: false,
                        ),
                      );
                      sink.add(ProtobufCodec.encode(reply));
                      notificationTimer?.cancel();
                      notificationTimer = Timer.periodic(
                        const Duration(minutes: 5),
                        (timer) {
                          if (ws.isClosed) {
                            timer.cancel();
                            notificationTimer?.cancel();
                            return;
                          }
                          sink.add(ProtobufCodec.encode(pb.Reply(
                            push: pb.Push(
                              channel: 'notification:index',
                              message: pb.Message(
                                data: utf8.encode(
                                    DateTime.now().toUtc().toIso8601String()),
                              ),
                            ),
                          )));
                        },
                      );
                    } else if (command.hasUnsubscribe() &&
                        command.unsubscribe.channel == 'notification:index') {
                      final reply = pb.Reply(
                        id: command.id,
                        unsubscribe: pb.UnsubscribeResult(),
                      );
                      sink.add(ProtobufCodec.encode(reply));
                      notificationTimer?.cancel();
                    } else if (command.hasSubscribe() &&
                        command.subscribe.channel == 'echo:index') {
                      final reply = pb.Reply(
                        id: command.id,
                        subscribe: pb.SubscribeResult(
                          data: utf8.encode('echo:index'),
                          epoch: '...',
                          offset: offset,
                          expires: false,
                          ttl: null,
                          positioned: false,
                          publications: <pb.Publication>[
                            pb.Publication(
                              offset: offset,
                              data: const <int>[1, 2, 3],
                              info: pb.ClientInfo(
                                client: 'fake',
                                user: 'fake',
                              ),
                              tags: const <String, String>{
                                'type': 'echo',
                              },
                            ),
                          ],
                          recoverable: false,
                          recovered: false,
                          wasRecovering: false,
                        ),
                      );
                      sink.add(ProtobufCodec.encode(reply));
                      echo = true;
                    } else if (command.hasUnsubscribe() &&
                        command.unsubscribe.channel == 'echo:index') {
                      final reply = pb.Reply(
                        id: command.id,
                        unsubscribe: pb.UnsubscribeResult(),
                      );
                      sink.add(ProtobufCodec.encode(reply));
                      echo = false;
                    }
                  });
                };
            },
          )
            ..connect(url)
            ..newSubscription('notification:index')
            ..newSubscription('echo:index')
            ..subscriptions.client.values.forEach((s) => s.subscribe());
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
          expect(client.subscriptions.server, isEmpty);
          expect(
            client.subscriptions.client,
            allOf(
              isNotEmpty,
              hasLength(2),
            ),
          );
          for (final sub in client.subscriptions.client.values) {
            expect(
              sub.state,
              isA<SpinifySubscriptionState$Unsubscribed>(),
            );
            expectLater(
              sub.states,
              emitsInOrder([
                isA<SpinifySubscriptionState$Subscribing>(),
                isA<SpinifySubscriptionState$Subscribed>(),
                isA<SpinifySubscriptionState$Unsubscribed>(),
                emitsDone,
              ]),
            );
          }
          async.elapse(client.config.timeout);
          expect(client.state.isConnected, isTrue);
          expectLater(
            client.subscriptions.client['notification:index']?.stream.message(),
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
          final echoEvents = <SpinifyChannelEvent>[];
          client.subscriptions.client['echo:index']?.stream
              .forEach(echoEvents.add);
          for (var i = 0; i < 10; i++) {
            async.elapse(const Duration(minutes: 5));
            client.publish('echo:index', utf8.encode(i.toString()));
          }
          async.elapse(const Duration(days: 1));
          expect(client.state.isConnected, isTrue);
          expect(client.subscriptions.client, isNotEmpty);
          pingTimer?.cancel();
          client.close();
          async.elapse(client.config.timeout);
          expect(client.subscriptions.client, isEmpty);
          expect(
            echoEvents,
            equals([
              for (var i = 0; i < 10; i++)
                isA<SpinifyPublication>()
                    .having(
                      (m) => m.data,
                      'data',
                      equals(utf8.encode(i.toString())),
                    )
                    .having(
                      (m) => m.offset,
                      'offset',
                      equals(Int64(i + 1)),
                    ),
            ]),
          );
          expect(client.state.isConnected, isFalse);
          expect(client.isClosed, isTrue);
        },
      ),
    );

    test(
      'History',
      () => fakeAsync(
        (async) {
          Timer? pingTimer;
          final client = createFakeClient(transport: (_) async {
            pingTimer?.cancel();
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
                  } else if (command.hasSubscribe() &&
                      command.subscribe.channel == 'publications:index') {
                    final reply = pb.Reply(
                      id: command.id,
                      subscribe: pb.SubscribeResult(
                        data: utf8.encode('publications:index'),
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
                    );
                    sink.add(ProtobufCodec.encode(reply));
                  } else if (command.hasHistory() &&
                      command.history.channel == 'publications:index') {
                    final reply = pb.Reply(
                      id: command.id,
                      history: pb.HistoryResult(
                        epoch: '...',
                        offset: Int64.ZERO,
                        publications: <pb.Publication>[
                          for (var i = 0; i < 256; i++)
                            pb.Publication(
                              offset: Int64(i),
                              data: <int>[
                                for (var j = 0; j < 256; j++) j & 0xFF,
                              ],
                              info: pb.ClientInfo(
                                client: 'fake',
                                user: 'fake',
                              ),
                              tags: const <String, String>{
                                'type': 'notification',
                              },
                            ),
                        ],
                      ),
                    );
                    sink.add(ProtobufCodec.encode(reply));
                  } else {
                    debugger();
                  }
                });
              };
          })
            ..connect(url);
          async.elapse(client.config.timeout);
          expect(client.state.isConnected, isTrue);
          async.elapse(const Duration(days: 1));
          expect(client.state.isConnected, isTrue);
          final channel = client.newSubscription('publications:index');
          expect(client.subscriptions.client['publications:index'], isNotNull);
          expect(channel.state.isSubscribed, isFalse);
          channel.subscribe(); // Start subscription
          async.elapse(client.config.timeout);
          expect(channel.state.isSubscribed, isTrue); // Subscribed
          final history = channel.history(); // Get history
          async.elapse(const Duration(seconds: 1));
          expect(
            history,
            completion(
              isA<SpinifyHistory>().having(
                (h) => h.publications,
                'publications',
                allOf(
                  isA<List<SpinifyPublication>>(),
                  hasLength(256), // 256 publications
                ),
              ),
            ),
          ); // History received
          async.elapse(client.config.timeout);
          pingTimer?.cancel();
          client.close(); // Close connection
          async.elapse(const Duration(seconds: 10));
          expect(client.state.isClosed, isTrue);
          expect(channel.state.isUnsubscribed, isTrue);
        },
      ),
    );
  });
}
