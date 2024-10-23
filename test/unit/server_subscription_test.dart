import 'package:fake_async/fake_async.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:spinify/spinify.dart';
import 'package:test/test.dart';

import 'server_subscription_test.mocks.dart';

@GenerateNiceMocks([MockSpec<WebSocket>(as: #MockWebSocket)])
void main() {
  group('SpinifyServerSubscription', () {
    test(
      'Emulate server subscription',
      () => fakeAsync(
        (async) {
          final ws = MockWebSocket();
          when(ws.stream).thenAnswer(
            (_) => Stream.fromIterable(
              const <List<int>>[
                <int>[0, 0, 0, 0, 0, 0, 0, 0],
              ],
            ),
          );
          when(ws.isClosed).thenReturn(false);
          when(ws.add(any)).thenAnswer((_) {});
          when(ws.close()).thenAnswer((_) {});
          // TODO: Encode response data for mocks
          // Mike Matiunin <plugfox@gmail.com>, 24 October 2024

          /* final client = Spinify(
            config: SpinifyConfig(
              transportBuilder: $createFakeSpinifyTransport(
                overrideCommand: (command) => switch (command) {
                  SpinifyConnectRequest request => SpinifyConnectResult(
                      id: request.id,
                      timestamp: DateTime.now(),
                      client: 'fake',
                      version: '0.0.1',
                      expires: false,
                      ttl: null,
                      data: null,
                      subs: <String, SpinifySubscribeResult>{
                        'notification:index': SpinifySubscribeResult(
                          id: request.id,
                          timestamp: DateTime.now(),
                          data: const <int>[],
                          expires: false,
                          ttl: null,
                          positioned: false,
                          publications: <SpinifyPublication>[
                            SpinifyPublication(
                              channel: 'notification:index',
                              data: const <int>[],
                              info: SpinifyClientInfo(
                                client: 'fake',
                                user: 'fake',
                                channelInfo: const <int>[],
                                connectionInfo: const <int>[],
                              ),
                              timestamp: DateTime.now(),
                              tags: const <String, String>{
                                'type': 'notification',
                              },
                              offset: Int64.ZERO,
                            ),
                          ],
                          recoverable: false,
                          recovered: false,
                          since: (epoch: '...', offset: Int64.ZERO),
                          wasRecovering: false,
                        ),
                      },
                      pingInterval: const Duration(seconds: 25),
                      sendPong: false,
                      session: 'fake',
                      node: 'fake',
                    ),
                  _ => null,
                },
              ),
            ),
          )..connect('ws://localhost:8000/connection/websocket');
          async.elapse(client.config.timeout);
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
          ); */
        },
      ),
    );
  });
}
