import 'package:spinify/spinify.dart';
import 'package:test/test.dart';

void main() {
  group('Spinify', () {
    test('Create_and_close_client', () async {
      final client = Spinify();
      expect(client.isClosed, isFalse);
      expect(client.state, isA<SpinifyState$Disconnected>());
      await client.close();
      expect(client.isClosed, isTrue);
      expect(client.state, isA<SpinifyState$Closed>());
    });

    test('Create_and_close_multiple_clients', () async {
      final clients = List.generate(10, (_) => Spinify());
      expect(clients.every((client) => !client.isClosed), isTrue);
      await Future.wait(clients.map((client) => client.close()));
      expect(clients.every((client) => client.isClosed), isTrue);
    });

    /* const url = 'ws://localhost:8000/connection/websocket';
      test('Connection', () async {
        final client = Spinify();
        await client.connect(url);
        expect(client.state, isA<SpinifyState$Connected>());
        await client.disconnect();
        expect(client.state, isA<SpinifyState$Disconnected>());
      }); */
  });
}
