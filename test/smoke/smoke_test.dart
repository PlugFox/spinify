import 'dart:convert';

import 'package:spinify/spinify.dart';
import 'package:test/test.dart';

void main() {
  group('Smoke test', () {
    const url = 'ws://localhost:8000/connection/websocket';
    test('Connection', () async {
      final client = Spinify();
      await client.connect(url);
      expect(client.state, isA<SpinifyState$Connected>());
      await client.send(utf8.encode('Hello, Spinify!'));
      await client.disconnect();
      expect(client.state, isA<SpinifyState$Disconnected>());
      await client.close();
      expect(client.state, isA<SpinifyState$Closed>());
    });
  });
}
