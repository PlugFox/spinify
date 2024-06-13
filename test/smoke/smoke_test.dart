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

    test('Disconnect_temporarily', () async {
      final client = Spinify(
        config: SpinifyConfig(
          connectionRetryInterval: (
            min: const Duration(milliseconds: 50),
            max: const Duration(milliseconds: 150),
          ),
        ),
      );
      await client.connect(url);
      expect(client.state, isA<SpinifyState$Connected>());
      await client.rpc('disconnect', utf8.encode('reconnect'));
      // await client.stream.disconnect().first;
      await client.states.disconnected.first;
      expect(client.state, isA<SpinifyState$Disconnected>());
      expect(
        client.metrics,
        isA<SpinifyMetrics>()
            .having(
              (m) => m.connects,
              'connects = 1',
              equals(1),
            )
            .having(
              (m) => m.disconnects,
              'disconnects = 1',
              equals(1),
            )
            .having(
              (m) => m.reconnectUrl,
              'reconnectUrl is set',
              isNotNull,
            )
            .having(
              (m) => m.nextReconnectAt,
              'nextReconnectAt is set',
              isNotNull,
            ),
      );
      await client.states.connecting.first;
      await client.states.connected.first;
      expect(client.state, isA<SpinifyState$Connected>());
      await client.close();
      expect(client.state, isA<SpinifyState$Closed>());
    });

    test('Disconnect_permanent', () async {
      final client = Spinify(
        config: SpinifyConfig(
          connectionRetryInterval: (
            min: const Duration(milliseconds: 50),
            max: const Duration(milliseconds: 150),
          ),
        ),
      );
      await client.connect(url);
      expect(client.state, isA<SpinifyState$Connected>());
      await client.rpc('disconnect');
      await client.states.disconnected.first;
      expect(client.state, isA<SpinifyState$Disconnected>());
      expect(
        client.metrics,
        isA<SpinifyMetrics>()
            .having(
              (m) => m.connects,
              'connects = 1',
              equals(1),
            )
            .having(
              (m) => m.disconnects,
              'disconnects = 1',
              equals(1),
            )
            .having(
              (m) => m.reconnectUrl,
              'reconnectUrl is not set',
              isNull,
            )
            .having(
              (m) => m.nextReconnectAt,
              'nextReconnectAt is not set',
              isNull,
            ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(client.state, isA<SpinifyState$Disconnected>());
      await client.close();
      expect(client.state, isA<SpinifyState$Closed>());
    });
  });
}
