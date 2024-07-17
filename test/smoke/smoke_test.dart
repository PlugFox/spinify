// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:spinify/spinify.dart';
import 'package:test/test.dart';

extension type _SpinifyChannelEventView(SpinifyChannelEvent event) {}

void main() {
  const url = 'ws://localhost:8000/connection/websocket';
  const enablePrint =
      bool.fromEnvironment('TEST_ENABLE_PRINT', defaultValue: false);
  final logBuffer = SpinifyLogBuffer(size: 100);

  void loggerPrint(SpinifyLogLevel level, String event, String message,
          Map<String, Object?> context) =>
      print('[$event] $message');

  SpinifyReply? $prevPeply; // ignore: unused_local_variable
  void loggerCheckReply(SpinifyLogLevel level, String event, String message,
      Map<String, Object?> context) {
    if (context['reply'] case SpinifyReply reply) {
      expect(
        reply,
        isA<SpinifyReply>()
            .having((r) => r.id, 'id', isNonNegative)
            .having((r) => r.timestamp, 'timestamp', isA<DateTime>())
            .having((r) => r.type, 'type', isNotEmpty)
            .having((r) => r.isResult, 'isResult',
                equals(reply is SpinifyReplyResult))
            .having((r) => r.toString(), 'toString()', isNotEmpty),
      );
      expect(reply.hashCode, equals(reply.hashCode));
      if (reply is SpinifyPush) {
        expect(reply.channel, equals(reply.event.channel));
      }
      if ($prevPeply != null) {
        expect(() => reply == $prevPeply, returnsNormally);
        expect(reply.compareTo($prevPeply!), isNonNegative);
      }
      $prevPeply = reply;
    }
  }

  SpinifyChannelEvent? $prevEvent;
  void loggerCheckEvents(SpinifyLogLevel level, String event, String message,
      Map<String, Object?> context) {
    if (context['event'] case SpinifyChannelEvent event) {
      expect(
        event,
        isA<SpinifyChannelEvent>()
            .having((s) => s.channel, 'channel', isNotNull)
            .having((s) => s.type, 'type', isNotEmpty)
            .having((s) => s.toString(), 'toString()', isNotEmpty)
            .having(
              (s) => s,
              'equals',
              equals(_SpinifyChannelEventView(event)),
            ),
      );
      expect(
        event.mapOrNull(
              publication: (e) => e.isPublication,
              presence: (e) => e.isPresence,
              unsubscribe: (e) => e.isUnsubscribe,
              message: (e) => e.isMessage,
              subscribe: (e) => e.isSubscribe,
              connect: (e) => e.isConnect,
              disconnect: (e) => e.isDisconnect,
              refresh: (e) => e.isRefresh,
            ) ??
            false,
        isTrue,
      );
      if ($prevEvent != null) {
        expect(event.compareTo($prevEvent!), isNonNegative);
      }
      $prevEvent = event;
    }
  }

  void logger(SpinifyLogLevel level, String event, String message,
      Map<String, Object?> context) {
    final args = [level, event, message, context];
    if (enablePrint) Function.apply(loggerPrint, args);
    Function.apply(logBuffer.add, args);
    Function.apply(loggerCheckReply, args);
    Function.apply(loggerCheckEvents, args);
  }

  ISpinify createClient() => Spinify(
        config: SpinifyConfig(
          connectionRetryInterval: (
            min: const Duration(milliseconds: 50),
            max: const Duration(milliseconds: 150),
          ),
          logger: logger,
        ),
      );

  group('Connection', () {
    test('Connect_and_disconnect', () async {
      final client = createClient();
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
      final client = createClient();
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
      final client = createClient();
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
      final client = createClient();
      await client.connect(url);
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
      final client = createClient();
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
