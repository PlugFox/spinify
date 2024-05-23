import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:spinify/spinify.dart';
import 'package:test/test.dart';

void main() {
  group('Spinify', () {
    Spinify createFakeClient([
      void Function(ISpinifyTransport transport)? out,
    ]) =>
        Spinify(
          config: SpinifyConfig(
            transportBuilder: $createFakeSpinifyTransport(out),
          ),
        );

    test('Create_and_close_client', () async {
      final client = createFakeClient();
      expect(client.isClosed, isFalse);
      expect(client.state, isA<SpinifyState$Disconnected>());
      await client.close();
      expect(client.state, isA<SpinifyState$Closed>());
      expect(client.isClosed, isTrue);
    });

    test('Create_and_close_multiple_clients', () async {
      final clients = List.generate(10, (_) => createFakeClient());
      expect(clients.every((client) => !client.isClosed), isTrue);
      await Future.wait(clients.map((client) => client.close()));
      expect(clients.every((client) => client.isClosed), isTrue);
    });

    test('Change_client_state', () async {
      final client = createFakeClient();
      expect(client.state, isA<SpinifyState$Disconnected>());
      await client.connect('ws://localhost:8000/connection/websocket');
      expect(client.state, isA<SpinifyState$Connected>());
      await client.disconnect();
      expect(client.state, isA<SpinifyState$Disconnected>());
      await client.close();
      expect(client.state, isA<SpinifyState$Closed>());
    });

    test('Change_client_states', () {
      final client = createFakeClient();
      Stream.fromIterable([
        () => client.connect('ws://localhost:8000/connection/websocket'),
        client.disconnect,
        () => client.connect('ws://localhost:8000/connection/websocket'),
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
    });

    test(
        'Reconnect_after_disconnected_transport',
        () => fakeAsync((async) {
              ISpinifyTransport? transport;
              final client = createFakeClient((t) => transport = t)
                ..connect('ws://localhost:8000/connection/websocket');
              expect(client.state, isA<SpinifyState$Connecting>());
              async.elapse(client.config.timeout);
              expect(client.state, isA<SpinifyState$Connected>());
              expect(transport, isNotNull);
              expect(transport, isA<SpinifyTransportFake>());
              transport!.disconnect();
              async.elapse(const Duration(milliseconds: 50));
              expect(client.state, isA<SpinifyState$Disconnected>());
              async.elapse(Duration(
                  milliseconds: client
                          .config.connectionRetryInterval.min.inMilliseconds ~/
                      2));
              expect(client.state, isA<SpinifyState$Disconnected>());
              async.elapse(client.config.connectionRetryInterval.max);
              expect(client.state, isA<SpinifyState$Connected>());
              client.close();
              expectLater(
                  client.states,
                  emitsInOrder([
                    isA<SpinifyState$Disconnected>(),
                    isA<SpinifyState$Closed>()
                  ]));
              async.elapse(client.config.connectionRetryInterval.max);
              expect(client.state, isA<SpinifyState$Closed>());
            }));

    test(
        'rpc_request',
        () => fakeAsync((async) {
              final client = createFakeClient()
                ..connect('ws://localhost:8000/connection/websocket');
              expect(client.state, isA<SpinifyState$Connecting>());
              async.elapse(client.config.timeout);
              expect(client.state, isA<SpinifyState$Connected>());

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
              client.close();
              async.elapse(client.config.timeout);
              expect(client.state, isA<SpinifyState$Closed>());
            }));
  });
}
