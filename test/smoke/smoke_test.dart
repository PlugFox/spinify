// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:spinify/spinify.dart';
import 'package:test/test.dart';

void main() {
  const url = 'ws://localhost:8000/connection/websocket';

  group('Connection', () {
    // ignore: unused_element
    void logger(SpinifyLogLevel level, String event, String message,
            Map<String, Object?> context) =>
        print('[$event] $message');

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
            /* logger: logger, */
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
          /* logger: logger, */
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
      await Future<void>.delayed(const Duration(milliseconds: 250));
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
          /* logger: logger, */
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

  group('Subscriptions', () {
    test('Server_subscription', () async {
      final client = Spinify();
      await client.connect(url);
      expect(client.state, isA<SpinifyState$Connected>());
      final serverSubscriptions = client.subscriptions.server;
      expect(
        serverSubscriptions,
        isA<Map<String, SpinifyServerSubscription>>()
            .having(
              (subs) => subs.keys,
              'server subscriptions',
              containsAll(<String>['notification:index']),
            )
            .having(
              (subs) => subs['notification:index'],
              'publications',
              isA<SpinifyServerSubscription>()
                  .having(
                    (sub) => sub.channel,
                    'channel',
                    'notification:index',
                  )
                  .having(
                    (sub) => sub.state,
                    'state',
                    isA<SpinifySubscriptionState$Subscribed>(),
                  ),
            ),
      );
      final notification = serverSubscriptions['notification:index'];
      expect(
        notification,
        allOf(
          isNotNull,
          isA<SpinifyServerSubscription>()
              .having((sub) => sub.state.isSubscribed, 'subscribed', isTrue),
        ),
      );
      notification!;
      await expectLater(
        notification.history,
        throwsA(
          isA<SpinifyReplyException>()
              .having(
                (e) => e.replyCode,
                'replyCode',
                equals(108),
              )
              .having(
                (e) => e.message.trim().toLowerCase(),
                'message',
                equals('not available'),
              ),
        ),
      );
      await expectLater(notification.presence(), completes);
      await expectLater(
        notification.presenceStats,
        throwsA(
          isA<SpinifyReplyException>()
              .having(
                (e) => e.replyCode,
                'replyCode',
                equals(108),
              )
              .having(
                (e) => e.message.trim().toLowerCase(),
                'message',
                equals('not available'),
              ),
        ),
      );
      await client.close();
      expect(client.state, isA<SpinifyState$Closed>());
      expect(notification.state.isUnsubscribed, isTrue);
      expect(serverSubscriptions, isEmpty);
    });
  });
}
