// ignore_for_file: non_const_call_to_literal_constructor

import 'package:fixnum/fixnum.dart';
import 'package:spinify/src/model/annotations.dart' as annotations;
import 'package:spinify/src/model/channel_event.dart' as channel_event;
import 'package:spinify/src/model/channel_events.dart' as channel_events;
import 'package:spinify/src/model/client_info.dart' as client_info;
import 'package:spinify/src/model/codes.dart' as codes;
import 'package:spinify/src/model/command.dart' as command;
import 'package:spinify/src/model/exception.dart' as exception;
import 'package:spinify/src/model/history.dart' as history;
import 'package:spinify/src/model/presence_stats.dart' as presence_stats;
import 'package:spinify/src/util/list_equals.dart';
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

    group('Channel_events', () {
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

      test('Streams', () {
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
        for (var i = 0; i < events.length; i++) {
          final event = events[i];
          channel_events.SpinifyChannelEvents stream() =>
              channel_events.SpinifyChannelEvents(Stream.value(event));
          expect(
            stream(),
            allOf(
              isA<Stream<channel_event.SpinifyChannelEvent>>(),
              isA<channel_events.SpinifyChannelEvents>(),
            ),
          );
          expectLater(
            stream(),
            emitsInOrder([
              same(event),
              emitsDone,
            ]),
          );
          expectLater(
            stream().filter(channel: 'another'),
            emitsDone,
          );
          expectLater(
            stream().filter(channel: channel),
            emitsInOrder([
              same(event),
              emitsDone,
            ]),
          );
          expectLater(
            stream().publication(channel: channel),
            emitsInOrder([
              if (event.isPublication) same(event),
              emitsDone,
            ]),
          );
          expectLater(
            stream().presence(channel: channel),
            emitsInOrder([
              if (event.isPresence) same(event),
              emitsDone,
            ]),
          );
          expectLater(
            stream().unsubscribe(channel: channel),
            emitsInOrder([
              if (event.isUnsubscribe) same(event),
              emitsDone,
            ]),
          );
          expectLater(
            stream().message(channel: channel),
            emitsInOrder([
              if (event.isMessage) same(event),
              emitsDone,
            ]),
          );
          expectLater(
            stream().subscribe(channel: channel),
            emitsInOrder([
              if (event.isSubscribe) same(event),
              emitsDone,
            ]),
          );
          expectLater(
            stream().connect(channel: channel),
            emitsInOrder([
              if (event.isConnect) same(event),
              emitsDone,
            ]),
          );
          expectLater(
            stream().disconnect(channel: channel),
            emitsInOrder([
              if (event.isDisconnect) same(event),
              emitsDone,
            ]),
          );
          expectLater(
            stream().refresh(channel: channel),
            emitsInOrder([
              if (event.isRefresh) same(event),
              emitsDone,
            ]),
          );
        }
      });

      test('Client_info', () {
        final info = client_info.SpinifyClientInfo(
          client: 'client',
          user: 'user',
          channelInfo: const [1, 2, 3],
          connectionInfo: const [4, 5, 6],
        );
        expect(info, isA<client_info.SpinifyClientInfo>());
        expect(
          info.toString(),
          allOf(
            isA<String>(),
            isNotEmpty,
            startsWith('SpinifyClientInfo{'),
            endsWith('}'),
          ),
        );
        expect(info == info, isTrue);
        expect(
          listEquals(
            info.channelInfo,
            info.channelInfo?.toList(growable: false),
          ),
          isTrue,
        );
        expect(
          listEquals(
            info.connectionInfo,
            info.connectionInfo?.toList(growable: false),
          ),
          isTrue,
        );
        expect(
          info ==
              client_info.SpinifyClientInfo(
                user: info.user,
                client: info.client,
                connectionInfo: info.connectionInfo?.toList(growable: false),
                channelInfo: info.channelInfo?.toList(growable: false),
              ),
          isTrue,
        );
        expect(
          info ==
              client_info.SpinifyClientInfo(
                user: info.user,
                client: info.client,
                connectionInfo: info.connectionInfo?.toList(growable: false),
                channelInfo: const [7, 8, 9],
              ),
          isFalse,
        );
      });

      test('Publications', () {
        final publication1 = channel_event.SpinifyPublication(
          timestamp: DateTime.now(),
          channel: 'channel',
          data: const [1, 2, 3],
          offset: Int64(10),
          info: client_info.SpinifyClientInfo(
            channelInfo: const [1, 2, 3],
            client: 'client',
            connectionInfo: const [4, 5, 6],
            user: 'user',
          ),
          tags: const {'key': 'value'},
        );
        final publication2 = channel_event.SpinifyPublication(
          timestamp: publication1.timestamp,
          channel: publication1.channel,
          offset: publication1.offset,
          info: publication1.info,
          data: [...publication1.data],
          tags: {...?publication1.tags},
        );
        expect(publication1, isA<channel_event.SpinifyPublication>());
        expect(publication1.hashCode, isPositive);
        expect(
          publication1.toString(),
          allOf(
            isA<String>(),
            isNotEmpty,
            startsWith('Publication{'),
            endsWith('}'),
          ),
        );
        expect(publication1, equals(publication1));
        expect(publication1, equals(publication2));
      });

      test('History', () {
        final history1 = history.SpinifyHistory(
          publications: [
            channel_event.SpinifyPublication(
              timestamp: DateTime.now(),
              channel: 'channel',
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
          ],
          since: (
            epoch: 'epoch',
            offset: Int64(10),
          ),
        );
        final history2 = history.SpinifyHistory(
          publications: [
            ...history1.publications,
          ],
          since: history1.since,
        );
        expect(history1, isA<history.SpinifyHistory>());
        expect(history1.hashCode, isPositive);
        expect(
          history1.toString(),
          allOf(
            isA<String>(),
            isNotEmpty,
            startsWith('SpinifyHistory{'),
            endsWith('}'),
          ),
        );
        expect(
          listEquals(history1.publications, history2.publications),
          isTrue,
        );
        expect(
          history1 == history2,
          isTrue,
        );
      });

      test('PresenceStats', () {
        const stats1 = presence_stats.SpinifyPresenceStats(
          channel: 'channel',
          clients: 5,
          users: 3,
        );
        final stats2 = presence_stats.SpinifyPresenceStats(
          channel: stats1.channel,
          clients: stats1.clients,
          users: stats1.users,
        );
        const stats3 = presence_stats.SpinifyPresenceStats(
          channel: 'another',
          clients: 6,
          users: 4,
        );
        expect(stats1, isA<presence_stats.SpinifyPresenceStats>());
        expect(stats1.hashCode, isPositive);
        expect(
          stats1.toString(),
          allOf(
            isA<String>(),
            isNotEmpty,
            startsWith('SpinifyPresenceStats{'),
            endsWith('}'),
          ),
        );
        expect(stats1, equals(stats1));
        expect(stats1, equals(stats2));
        expect(stats1, isNot(equals(stats3)));
      });
    });

    group('Commands', () {
      test('Instances', () {
        const id = 1;
        final timestamp = DateTime.now();
        const channel = 'channel';
        const token = 'token';
        final commands = <command.SpinifyCommand>[
          command.SpinifyConnectRequest(
            id: id,
            timestamp: timestamp,
            data: const [1, 2, 3],
            name: 'name',
            token: token,
            version: 'version',
            subs: {
              channel: command.SpinifySubscribeRequest(
                channel: channel,
                data: const [1, 2, 3],
                epoch: 'epoch',
                joinLeave: true,
                offset: Int64(10),
                positioned: true,
                recover: true,
                recoverable: true,
                id: id,
                timestamp: timestamp,
                token: token,
              ),
            },
          ),
          command.SpinifySubscribeRequest(
            channel: channel,
            data: const [1, 2, 3],
            epoch: 'epoch',
            joinLeave: true,
            offset: Int64(10),
            positioned: true,
            recover: true,
            recoverable: true,
            id: id,
            timestamp: timestamp,
            token: token,
          ),
          command.SpinifyUnsubscribeRequest(
            channel: channel,
            id: id,
            timestamp: timestamp,
          ),
          command.SpinifyPublishRequest(
            channel: channel,
            data: const [1, 2, 3],
            id: id,
            timestamp: timestamp,
          ),
          command.SpinifyPingRequest(
            timestamp: timestamp,
          ),
          command.SpinifyPresenceRequest(
            channel: channel,
            id: id,
            timestamp: timestamp,
          ),
          command.SpinifyPresenceStatsRequest(
            channel: channel,
            id: id,
            timestamp: timestamp,
          ),
          command.SpinifyHistoryRequest(
            channel: channel,
            id: id,
            timestamp: timestamp,
            limit: 10,
            reverse: true,
            since: (epoch: token, offset: Int64(10)),
          ),
          command.SpinifySendRequest(
            data: const [1, 2, 3],
            timestamp: timestamp,
          ),
          command.SpinifyRPCRequest(
            data: const [1, 2, 3],
            id: id,
            timestamp: timestamp,
            method: 'method',
          ),
          command.SpinifyRefreshRequest(
            id: id,
            timestamp: timestamp,
            token: token,
          ),
          command.SpinifySubRefreshRequest(
            id: id,
            timestamp: timestamp,
            token: token,
            channel: channel,
          ),
        ];

        for (var i = 0; i < commands.length; i++) {
          final c = commands[i];
          expect(
            c,
            isA<command.SpinifyCommand>()
                .having(
                  (e) => e.id,
                  'id',
                  c.hasId ? equals(id) : equals(0),
                )
                .having(
                  (e) => e.timestamp,
                  'timestamp',
                  same(timestamp),
                )
                .having(
                  (e) => e.type,
                  'type',
                  isNotEmpty,
                )
                .having(
                  (e) => e.hashCode,
                  'hashCode',
                  isPositive,
                )
                .having(
                  (e) => e.toString(),
                  'toString',
                  startsWith(c.type),
                ),
          );
          expect(c == c, isTrue);
          for (var j = 0; j < commands.length; j++) {
            final other = commands[j];
            expect(
              c == other,
              c.type == other.type,
            );
          }
        }

        expect(commands.sort, returnsNormally);

        final ping1 = command.SpinifyPingRequest(
          timestamp: DateTime(2000),
        );
        final ping2 = command.SpinifyPingRequest(
          timestamp: DateTime(2001),
        );
        expect(ping1.compareTo(ping2), lessThan(0));
        expect(ping1 == ping2, isFalse);
      });
    });

    group('Exceptions', () {
      test('Instances', () {
        const message = 'message';
        final error = Exception('error');
        final exceptions = <exception.SpinifyException>[
          exception.SpinifyConnectionException(
            message: message,
            error: error,
          ),
          exception.SpinifyReplyException(
            replyCode: 1000,
            replyMessage: message,
            temporary: true,
            error: error,
          ),
          exception.SpinifyPingException(
            message: message,
            error: error,
          ),
          exception.SpinifySubscriptionException(
            message: message,
            error: error,
            channel: 'channel',
          ),
          exception.SpinifySendException(
            message: message,
            error: error,
          ),
          exception.SpinifyRPCException(
            error: error,
            message: message,
          ),
          exception.SpinifyFetchException(
            error: error,
            message: message,
          ),
          exception.SpinifyRefreshException(
            error: error,
            message: message,
          ),
          exception.SpinifyTransportException(
            error: error,
            message: message,
            data: const [1, 2, 3],
          ),
        ];

        for (var i = 0; i < exceptions.length; i++) {
          final e = exceptions[i];
          expect(
            e,
            isA<exception.SpinifyException>()
                .having(
                  (e) => e.message,
                  'message',
                  equals(message),
                )
                .having(
                  (e) => e.error,
                  'error',
                  same(error),
                )
                .having(
                  (e) => e.hashCode,
                  'hashCode',
                  isPositive,
                )
                .having(
                  (e) => e.toString(),
                  'toString',
                  message,
                ),
          );

          expect(e == e, isTrue);
        }
      });

      test('Visitor', () {
        final e = exception.SpinifyPingException(
          error: exception.SpinifyPingException(
            error: exception.SpinifyPingException(
              error: exception.SpinifyPingException(
                error: Exception('Fake'),
              ),
            ),
          ),
        );

        final list = <Object>[];
        e.visitor(list.add);
        expect(list, hasLength(5));
      });
    });
  });
}
