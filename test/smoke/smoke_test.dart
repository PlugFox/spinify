// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:spinify/spinify.dart';
import 'package:test/test.dart';

void main() {
  group('Connection', () {
    const url = 'ws://localhost:8000/connection/websocket';

    test('Connect_and_disconnect', () async {
      final client = Spinify();
      await client.connect(url);
      expect(client.state, isA<SpinifyState$Connected>());
      //await client.ping();
      await client.send(utf8.encode('Hello from Spinify!'));
      await client.disconnect();
      expect(client.state, isA<SpinifyState$Disconnected>());
      await client.close();
      expect(client.state, isA<SpinifyState$Closed>());
    });

    test('Connect_and_refresh', () async {
      final client = Spinify(
        config: SpinifyConfig(
          logger: (level, event, message, context) =>
              print('[$event] $message'),
        ),
      );
      await client.connect(url);
      expect(client.state, isA<SpinifyState$Connected>());
      //await client.ping();
      await Future<void>.delayed(const Duration(seconds: 60));
      await client.disconnect();
      expect(client.state, isA<SpinifyState$Disconnected>());
      await client.close();
      expect(client.state, isA<SpinifyState$Closed>());
    }, timeout: const Timeout(Duration(minutes: 7)));
  });
}
