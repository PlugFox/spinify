// ignore_for_file: non_const_call_to_literal_constructor

import 'package:fixnum/fixnum.dart';
import 'package:spinify/src/model/annotations.dart' as annotations;
import 'package:spinify/src/model/channel_event.dart' as channel_event;
import 'package:spinify/src/model/client_info.dart' as client_info;
import 'package:spinify/src/model/codes.dart' as codes;
import 'package:test/test.dart';

void main() {
  group('Model', () {
    group('Annotations', () {
      test('Instances', () {
        expect(
          annotations.interactive,
          isA<annotations.SpinifyAnnotation>(),
        );
        expect(
          annotations.sideEffect,
          isA<annotations.SpinifyAnnotation>(),
        );
        expect(
          annotations.safe,
          isA<annotations.SpinifyAnnotation>(),
        );
        expect(
          annotations.unsafe,
          isA<annotations.SpinifyAnnotation>(),
        );
        expect(
          annotations.SpinifyAnnotation('name'),
          isA<annotations.SpinifyAnnotation>(),
        );
        expect(
          annotations.Throws(const [Exception]),
          isA<annotations.SpinifyAnnotation>(),
        );
      });

      test('Getters', () {
        expect(
          const annotations.Throws([Exception]),
          isA<annotations.Throws>()
              .having(
                (e) => e.name,
                'name',
                equals('throws'),
              )
              .having(
                (e) => e.meta,
                'meta',
                allOf(
                  isA<Map<String, Object?>>(),
                  isEmpty,
                ),
              )
              .having(
                (e) => e.exceptions,
                'exceptions',
                allOf(
                  isA<List<Type>>(),
                  hasLength(1),
                  contains(Exception),
                ),
              ),
        );
      });
    });

    group('Codes', () {
      test('Instances', () {
        expect(codes.SpinifyDisconnectCode.disconnect(), isA<int>());
        expect(codes.SpinifyDisconnectCode.noPingFromServer(), isA<int>());
        expect(codes.SpinifyDisconnectCode.internalServerError(), isA<int>());
        expect(codes.SpinifyDisconnectCode.unauthorized(), isA<int>());
        expect(codes.SpinifyDisconnectCode.unknownChannel(), isA<int>());
        expect(codes.SpinifyDisconnectCode.permissionDenied(), isA<int>());
        expect(codes.SpinifyDisconnectCode.methodNotFound(), isA<int>());
        expect(codes.SpinifyDisconnectCode.alreadySubscribed(), isA<int>());
        expect(codes.SpinifyDisconnectCode.limitExceeded(), isA<int>());
        expect(codes.SpinifyDisconnectCode.badRequest(), isA<int>());
        expect(codes.SpinifyDisconnectCode.notAvailable(), isA<int>());
        expect(codes.SpinifyDisconnectCode.tokenExpired(), isA<int>());
        expect(codes.SpinifyDisconnectCode.expired(), isA<int>());
        expect(codes.SpinifyDisconnectCode.tooManyRequests(), isA<int>());
        expect(codes.SpinifyDisconnectCode.unrecoverablePosition(), isA<int>());
        expect(codes.SpinifyDisconnectCode.normalClosure(), isA<int>());
        expect(codes.SpinifyDisconnectCode.abnormalClosure(), isA<int>());
      });

      test('Normalize', () {
        for (var i = -1; i <= 5000; i++) {
          final tuple = codes.SpinifyDisconnectCode.normalize(i);
          expect(
            tuple.code,
            allOf(isA<int>(), equals(i)),
          );
          expect(
            tuple.reason,
            allOf(isA<String>(), isNotEmpty),
          );
          expect(
            tuple.reconnect,
            allOf(isA<bool>(), same(tuple.code.reconnect)),
            reason: 'Code: $i should '
                '${tuple.code.reconnect ? '' : 'not '}'
                'reconnect',
          );
        }
      });
    });

    group('Channel_event', () {
      test('Variants', () {
        final now = DateTime.now();
        const channel = 'channel';
        final events = <channel_event.SpinifyChannelEvent>[
          channel_event.SpinifyPublication(
            timestamp: now,
            channel: channel,
            data: const [1, 2, 3],
            offset: Int64(10),
            info: client_info.SpinifyClientInfo(
              channelInfo: const [1, 2, 3],
              client: 'client',
              connectionInfo: const [4, 5, 6],
              user: 'user',
            ),
            tags: const {'key': 'value'},
          ),
          channel_event.SpinifyPresence.join(
            timestamp: now,
            channel: channel,
            info: client_info.SpinifyClientInfo(
              channelInfo: const [1, 2, 3],
              client: 'client',
              connectionInfo: const [4, 5, 6],
              user: 'user',
            ),
          ),
          channel_event.SpinifyPresence.leave(
            timestamp: now,
            channel: channel,
            info: client_info.SpinifyClientInfo(
              channelInfo: const [1, 2, 3],
              client: 'client',
              connectionInfo: const [4, 5, 6],
              user: 'user',
            ),
          ),
          channel_event.SpinifyUnsubscribe(
            timestamp: now,
            channel: channel,
            code: 1000,
            reason: 'reason',
          ),
          channel_event.SpinifySubscribe(
            timestamp: now,
            channel: channel,
            data: const [1, 2, 3],
            positioned: true,
            recoverable: true,
            since: (epoch: 'epoch', offset: Int64(10)),
          ),
          channel_event.SpinifyMessage(
            timestamp: now,
            channel: channel,
            data: const [1, 2, 3],
          ),
          channel_event.SpinifyConnect(
            timestamp: now,
            channel: channel,
            client: 'client',
            version: 'version',
            data: const [1, 2, 3],
            expires: true,
            ttl: now.add(const Duration(seconds: 10)),
            pingInterval: const Duration(seconds: 5),
            sendPong: true,
            session: 'session',
            node: 'node',
          ),
          channel_event.SpinifyDisconnect(
            timestamp: now,
            channel: channel,
            code: 1000,
            reason: 'reason',
            reconnect: true,
          ),
          channel_event.SpinifyRefresh(
            timestamp: now,
            channel: channel,
            expires: true,
            ttl: now.add(const Duration(seconds: 10)),
          ),
        ];

        for (final event in events) {
          expect(
            event,
            isA<channel_event.SpinifyChannelEvent>()
                .having(
                  (e) => e.runtimeType,
                  'runtimeType',
                  equals(event.runtimeType),
                )
                .having(
                  (e) => e.timestamp,
                  'timestamp',
                  same(now),
                )
                .having(
                  (e) => e.channel,
                  'channel',
                  same(channel),
                ),
          );

          expect(
            event.type,
            allOf(
              isA<String>(),
              isNotEmpty,
            ),
          );

          expect(
            event.toString(),
            equals('${event.type}{channel: $channel}'),
          );

          expect(
            event.mapOrNull<Object?>(
              connect: (e) => e,
              disconnect: (e) => e,
              message: (e) => e,
              presence: (e) => e,
              publication: (e) => e,
              refresh: (e) => e,
              subscribe: (e) => e,
              unsubscribe: (e) => e,
            ),
            allOf(
              isNotNull,
              isA<channel_event.SpinifyChannelEvent>(),
              same(event),
            ),
          );

          expect(
            event.mapOrNull<Object?>(),
            isNull,
          );

          expect(
            event.map<bool>(
              connect: (e) => e.isConnect,
              disconnect: (e) => e.isDisconnect,
              message: (e) => e.isMessage,
              presence: (e) => e.isPresence,
              publication: (e) => e.isPublication,
              refresh: (e) => e.isRefresh,
              subscribe: (e) => e.isSubscribe,
              unsubscribe: (e) => e.isUnsubscribe,
            ),
            allOf(
              isA<bool>(),
              isTrue,
            ),
          );

          expect(
            [
              event.isConnect,
              event.isDisconnect,
              event.isMessage,
              event.isPresence,
              event.isPublication,
              event.isRefresh,
              event.isSubscribe,
              event.isUnsubscribe,
            ],
            containsOnce(true),
          );
        }
        expect(events.sort, returnsNormally);
      });

      test('Presense', () {
        final now = DateTime.now();
        const channel = 'channel';
        final join = channel_event.SpinifyPresence.join(
          timestamp: now,
          channel: channel,
          info: client_info.SpinifyClientInfo(
            channelInfo: const [1, 2, 3],
            client: 'client',
            connectionInfo: const [4, 5, 6],
            user: 'user',
          ),
        );
        final leave = channel_event.SpinifyPresence.leave(
          timestamp: now,
          channel: channel,
          info: client_info.SpinifyClientInfo(
            channelInfo: const [1, 2, 3],
            client: 'client',
            connectionInfo: const [4, 5, 6],
            user: 'user',
          ),
        );

        expect(join.isJoin, isTrue);
        expect(leave.isLeave, isTrue);
        expect(join.isLeave, isFalse);
        expect(leave.isJoin, isFalse);
      });
    });
  });
}
