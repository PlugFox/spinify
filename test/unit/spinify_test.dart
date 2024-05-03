import 'package:spinify/spinify.old.dart';
import 'package:test/test.dart';

void main() => group('Spinify', () {
      const url = 'ws://localhost:8000/connection/websocket';
      test('Connection', () async {
        final client = Spinify();
        await client.connect(url);
        expect(client.state, isA<SpinifyState$Connected>());
        await client.disconnect();
        expect(client.state, isA<SpinifyState$Disconnected>());
      });
    });
