import 'package:centrifuge_dart/centrifuge.dart';
import 'package:test/test.dart';

void main() => group('Centrifuge', () {
      const url = 'ws://localhost:8000/connection/websocket';
      test('Connection', () async {
        final client = Centrifuge();
        await client.connect(url);
        expect(client.state, isA<CentrifugeState$Connected>());
        await client.disconnect();
        expect(client.state, isA<CentrifugeState$Disconnected>());
      });
    });
