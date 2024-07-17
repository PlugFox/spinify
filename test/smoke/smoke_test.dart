import 'dart:convert';

import 'package:spinify/spinify.dart';
import 'package:test/test.dart';

import 'create_client.dart';

void main() {
  group('Connection', () {
    test('Connect_and_disconnect', () async {
      final client = $createClient();
      await client.connect($url);
      expect(client.state, isA<SpinifyState$Connected>());
      //await client.ping();
      await client.send(utf8.encode('Hello from Spinify!'));
      await client.disconnect();
      expect(client.state, isA<SpinifyState$Disconnected>());
      await client.close();
      expect(client.state, isA<SpinifyState$Closed>());
    });

    test('Connect_and_refresh', () async {
      final client = $createClient();
      await client.connect($url);
      expect(client.state, isA<SpinifyState$Connected>());
      //await client.ping();
      await Future<void>.delayed(const Duration(seconds: 60));
      await client.disconnect();
      expect(client.state, isA<SpinifyState$Disconnected>());
      await client.close();
      expect(client.state, isA<SpinifyState$Closed>());
    }, timeout: const Timeout(Duration(minutes: 7)));

    test('Disconnect_temporarily', () async {
      final client = $createClient();
      await client.connect($url);
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
      final client = $createClient();
      await client.connect($url);
      expect(client.state, isA<SpinifyState$Connected>());
      await client.rpc('disconnect', utf8.encode('permanent'));
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
      final client = $createClient();
      await client.connect($url);
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
          equals(client.subscriptions.server['notification:index']),
          equals(client.getServerSubscription('notification:index')),
          equals(client.getSubscription('notification:index')),
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

    test('Client_subscription', () async {
      final client = $createClient();
      await client.connect($url);
      expect(client.state, isA<SpinifyState$Connected>());
      final sub = client.newSubscription('public:index');
      expect(
        sub,
        allOf(
          isNotNull,
          equals(client.subscriptions.client['public:index']),
          equals(client.getClientSubscription('public:index')),
          equals(client.getSubscription('public:index')),
          isA<SpinifyClientSubscription>().having(
              (sub) => sub.state.isUnsubscribed, 'unsubscribed', isTrue),
        ),
      );
      await expectLater(sub.subscribe(), completes);
      expect(sub.state.isSubscribed, isTrue);
      await expectLater(sub.unsubscribe(), completes);
      expect(sub.state.isUnsubscribed, isTrue);
      await expectLater(sub.subscribe(), completes);
      expect(sub.state.isSubscribed, isTrue);

      final messages = <String>[
        'Hello from',
        'Spinify!',
      ];

      // ignore: unawaited_futures
      expectLater(
          sub.stream
              .publication(channel: sub.channel)
              .map((p) => p.data)
              .map(utf8.decode)
              .map(jsonDecode)
              .cast<Map<String, Object?>>()
              .map((m) => m['input'])
              .cast<String>(),
          emitsInOrder([
            ...messages,
            emitsDone,
          ]));
      for (final message in messages) {
        await expectLater(
            sub.publish(utf8.encode(jsonEncode({
              'timestamp': DateTime.now().millisecondsSinceEpoch,
              'input': message,
            }))),
            completes);
      }
      await client.close();
      expect(client.state, isA<SpinifyState$Closed>());
      expect(sub.state.isUnsubscribed, isTrue);
    });
  });
}
