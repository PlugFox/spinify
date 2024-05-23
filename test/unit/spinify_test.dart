import 'package:spinify/spinify.dart';
import 'package:test/test.dart';

void main() {
  group('Spinify', () {
    Spinify createFakeClient() => Spinify(
          config: SpinifyConfig(
            transportBuilder: $createFakeSpinifyTransport,
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
  });
}
