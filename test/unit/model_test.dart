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
import 'package:spinify/src/model/metric.dart' as metric;
import 'package:spinify/src/model/presence_stats.dart' as presence_stats;
import 'package:spinify/src/model/reply.dart' as reply;
import 'package:spinify/src/model/state.dart' as state;
import 'package:spinify/src/model/states_stream.dart' as states_stream;
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

    group('Reply', () {
      test('Instances', () {
        const id = 1;
        final timestamp = DateTime.now();
        const channel = 'channel';
        final replies = <reply.SpinifyReply>[
          reply.SpinifyServerPing(
            timestamp: timestamp,
          ),
          reply.SpinifyPush(
            timestamp: timestamp,
            event: channel_event.SpinifyPublication(
              timestamp: timestamp,
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
          ),
          reply.SpinifyConnectResult(
            client: 'client',
            version: 'version',
            timestamp: timestamp,
            id: id,
            expires: true,
            ttl: timestamp.add(const Duration(seconds: 10)),
            data: const [1, 2, 3],
            node: 'node',
            pingInterval: const Duration(seconds: 5),
            sendPong: true,
            session: 'session',
            subs: <String, reply.SpinifySubscribeResult>{
              channel: reply.SpinifySubscribeResult(
                data: const [1, 2, 3],
                positioned: true,
                recoverable: true,
                id: id,
                timestamp: timestamp,
                expires: true,
                publications: [
                  channel_event.SpinifyPublication(
                    timestamp: timestamp,
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
                ],
                recovered: true,
                since: (epoch: 'epoch', offset: Int64(10)),
                ttl: timestamp.add(const Duration(seconds: 10)),
                wasRecovering: true,
              ),
            },
          ),
          reply.SpinifySubscribeResult(
            id: id,
            timestamp: timestamp,
            expires: true,
            ttl: timestamp.add(const Duration(seconds: 10)),
            recoverable: true,
            publications: [
              channel_event.SpinifyPublication(
                timestamp: timestamp,
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
            ],
            recovered: true,
            since: (epoch: 'epoch', offset: Int64(10)),
            data: const [1, 2, 3],
            positioned: true,
            wasRecovering: true,
          ),
          reply.SpinifyUnsubscribeResult(
            id: id,
            timestamp: timestamp,
          ),
          reply.SpinifyPublishResult(
            id: id,
            timestamp: timestamp,
          ),
          reply.SpinifyPresenceResult(
            id: id,
            timestamp: timestamp,
            presence: <String, client_info.SpinifyClientInfo>{
              channel: client_info.SpinifyClientInfo(
                channelInfo: const [1, 2, 3],
                client: 'client',
                user: 'user',
                connectionInfo: const [4, 5, 6],
              ),
            },
          ),
          reply.SpinifyPresenceStatsResult(
            id: id,
            timestamp: timestamp,
            numClients: 5,
            numUsers: 3,
          ),
          reply.SpinifyHistoryResult(
            id: id,
            timestamp: timestamp,
            publications: [
              channel_event.SpinifyPublication(
                timestamp: timestamp,
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
            ],
            since: (epoch: 'epoch', offset: Int64(10)),
          ),
          reply.SpinifyPingResult(
            id: id,
            timestamp: timestamp,
          ),
          reply.SpinifyRPCResult(
            id: id,
            timestamp: timestamp,
            data: const [1, 2, 3],
          ),
          reply.SpinifyRefreshResult(
            id: id,
            timestamp: timestamp,
            client: 'client',
            version: 'version',
            expires: true,
            ttl: timestamp.add(const Duration(seconds: 10)),
          ),
          reply.SpinifySubRefreshResult(
            id: id,
            timestamp: timestamp,
            expires: true,
            ttl: timestamp.add(const Duration(seconds: 10)),
          ),
          reply.SpinifyErrorResult(
            id: id,
            timestamp: timestamp,
            code: 1000,
            message: 'message',
            temporary: true,
          ),
        ];

        for (var i = 0; i < replies.length; i++) {
          final r = replies[i];
          expect(
            r,
            isA<reply.SpinifyReply>()
                .having(
                  (e) => e.id,
                  'id',
                  r.hasId ? equals(id) : equals(0),
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
                  startsWith(r.type),
                ),
          );

          expect(r.isResult, r.hasId);

          expect(
            r,
            anyOf(
              isNot(isA<reply.SpinifyPush>()),
              isA<reply.SpinifyPush>().having(
                (e) => e.channel == e.event.channel,
                'channel',
                isTrue,
              ),
            ),
          );

          for (var j = 0; j < replies.length; j++) {
            final other = replies[j];
            expect(
              r,
              r.type != other.type ? isNot(same(other)) : same(other),
            );
            expect(
              r,
              r.type != other.type ? isNot(equals(other)) : equals(other),
            );
          }
        }

        expect(replies.sort, returnsNormally);

        final ping1 = reply.SpinifyPingResult(
          timestamp: DateTime(2000),
          id: 1,
        );
        final ping2 = reply.SpinifyPingResult(
          timestamp: DateTime(2001),
          id: 1,
        );
        expect(ping1.compareTo(ping2), lessThan(0));
        expect(ping1, isNot(equals(ping2)));
      });
    });

    group('States', () {
      test('Instances', () {
        final timestamp = DateTime.now();
        final states = <state.SpinifyState>[
          state.SpinifyState.disconnected(
            timestamp: timestamp,
            temporary: false,
          ),
          state.SpinifyState.connecting(
            timestamp: timestamp,
            url: 'url',
          ),
          state.SpinifyState.connected(
            timestamp: timestamp,
            expires: true,
            ttl: timestamp.add(const Duration(seconds: 10)),
            url: 'url',
            client: 'client',
            data: const [1, 2, 3],
            node: 'node',
            pingInterval: const Duration(seconds: 5),
            sendPong: true,
            session: 'session',
            version: 'version',
          ),
          state.SpinifyState.closed(
            timestamp: timestamp,
          ),
        ];

        for (var i = 0; i < states.length; i++) {
          final s = states[i];
          expect(
            s,
            isA<state.SpinifyState>()
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
                  isNotEmpty,
                ),
          );

          expect(s.hashCode, isPositive);
          expect(s, equals(s));

          expect(
            s.mapOrNull<Object?>(
              connected: (e) => e,
              connecting: (e) => e,
              disconnected: (e) => e,
              closed: (e) => e,
            ),
            allOf(
              isNotNull,
              isA<state.SpinifyState>(),
              same(s),
            ),
          );

          expect(
            s.map<state.SpinifyState>(
              connected: (e) => state.SpinifyState$Connected(
                expires: e.expires,
                url: e.url,
                client: e.client,
                data: e.data,
                node: e.node,
                pingInterval: e.pingInterval,
                sendPong: e.sendPong,
                session: e.session,
                timestamp: DateTime(0),
                ttl: e.ttl,
                version: e.version,
              ),
              connecting: (e) => state.SpinifyState$Connecting(
                timestamp: DateTime(0),
                url: e.url,
              ),
              disconnected: (e) => state.SpinifyState$Disconnected(
                timestamp: DateTime(0),
                temporary: e.temporary,
              ),
              closed: (e) => state.SpinifyState$Closed(
                timestamp: DateTime(0),
              ),
            ),
            isNot(equals(s)),
          );

          expect(
            s.maybeMap<Object?>(
              orElse: () => 1,
            ),
            equals(1),
          );

          expect(s.mapOrNull<Object?>(), isNull);

          expect(
            s.map<bool>(
              closed: (e) => e.isClosed,
              connected: (e) => e.isConnected,
              connecting: (e) => e.isConnecting,
              disconnected: (e) => e.isDisconnected,
            ),
            isTrue,
          );

          expect(s.isDisconnected, isA<bool>());
          expect(s.isConnected, isA<bool>());
          expect(s.isConnecting, isA<bool>());
          expect(s.isClosed, isA<bool>());

          expect(
            s.url,
            anyOf(
              isNull,
              'url',
            ),
          );

          expect(
            s.mapOrNull<String?>(
              connected: (e) => e.url,
              connecting: (e) => e.url,
              closed: (e) => e.url,
              disconnected: (e) => e.url,
            ),
            anyOf(
              isNull,
              'url',
            ),
          );

          for (var j = 0; j < states.length; j++) {
            final other = states[j];
            expect(
              s,
              s.type != other.type ? isNot(same(other)) : same(other),
            );
            expect(
              s,
              s.type != other.type ? isNot(equals(other)) : equals(other),
            );
          }
        }

        expect(states.sort, returnsNormally);
      });

      test('Disconnected', () {
        final timestamp = DateTime.now();
        final state1 = state.SpinifyState$Disconnected(
          timestamp: timestamp,
          temporary: false,
        );
        final state2 = state.SpinifyState$Disconnected(
          timestamp: timestamp,
          temporary: false,
        );
        final state3 = state.SpinifyState$Disconnected(
          timestamp: timestamp.add(const Duration(seconds: 1)),
          temporary: true,
        );
        expect(state1, isA<state.SpinifyState>());
        expect(state1.hashCode, isPositive);
        expect(
          state1.toString(),
          isNotEmpty,
        );
        expect(state1, equals(state1));
        expect(state1, equals(state2));
        expect(state1, isNot(equals(state3)));
        expect(
          state1.permanent,
          isNot(state1.temporary),
        );
        expect(
          state3.permanent,
          isNot(state3.temporary),
        );
      });

      test('Stream', () {
        final timestamp = DateTime.now();
        final states = <state.SpinifyState>[
          state.SpinifyState.disconnected(
            timestamp: timestamp,
            temporary: false,
          ),
          state.SpinifyState.connecting(
            timestamp: timestamp,
            url: 'url',
          ),
          state.SpinifyState.connected(
            timestamp: timestamp,
            expires: true,
            ttl: timestamp.add(const Duration(seconds: 10)),
            url: 'url',
            client: 'client',
            data: const [1, 2, 3],
            node: 'node',
            pingInterval: const Duration(seconds: 5),
            sendPong: true,
            session: 'session',
            version: 'version',
          ),
          state.SpinifyState.closed(
            timestamp: timestamp,
          ),
        ];

        for (var i = 0; i < states.length; i++) {
          final s = states[i];
          states_stream.SpinifyStatesStream stream() =>
              states_stream.SpinifyStatesStream(Stream.value(s));

          expect(
            stream(),
            allOf(
              isA<Stream<state.SpinifyState>>(),
              isA<states_stream.SpinifyStatesStream>(),
            ),
          );

          expectLater(
            stream(),
            emitsInOrder([
              same(s),
              emitsDone,
            ]),
          );

          expectLater(
            stream().closed,
            emitsInOrder([
              if (s.isClosed) same(s),
              emitsDone,
            ]),
          );

          expectLater(
            stream().connected,
            emitsInOrder([
              if (s.isConnected) same(s),
              emitsDone,
            ]),
          );

          expectLater(
            stream().connecting,
            emitsInOrder([
              if (s.isConnecting) same(s),
              emitsDone,
            ]),
          );

          expectLater(
            stream().disconnected,
            emitsInOrder([
              if (s.isDisconnected) same(s),
              emitsDone,
            ]),
          );
        }
      });
    });

    group('Metric', () {
      test('Freeze', () {
        final mutable = metric.SpinifyMetrics$Mutable();
        expect(mutable.freeze, returnsNormally);
      });

      test('ToJson', () {
        final mutable = metric.SpinifyMetrics$Mutable();
        expect(mutable.toJson, returnsNormally);
      });

      test('ToString', () {
        final mutable = metric.SpinifyMetrics$Mutable();
        expect(
          mutable.toString(),
          allOf(
            isA<String>(),
            isNotEmpty,
            startsWith('SpinifyMetrics{'),
            endsWith('}'),
          ),
        );
      });

      test('CompareTo', () {
        final list = [
          metric.SpinifyMetrics$Mutable(),
          metric.SpinifyMetrics$Mutable(),
        ];
        expect(
          list.sort,
          returnsNormally,
        );
        expect(
          list.map((e) => e.freeze()).toList().sort,
          returnsNormally,
        );
      });

      test('Getters', () {
        final metrics = metric.SpinifyMetrics$Mutable();
        expect(metrics.messagesSent, isA<Int64>());
        expect(metrics.messagesReceived, isA<Int64>());
      });

      test('Channels', () {
        final m = metric.SpinifyMetrics$Mutable()
          ..channels.addAll({
            'channel': metric.SpinifyMetrics$Channel$Mutable(),
          });
        expect(m.channels, hasLength(1));
        expect(m.freeze, returnsNormally);
        expect(m.channels['channel'], isA<metric.SpinifyMetrics$Channel>());
        expect(
            m.channels['channel']!.toString(),
            allOf(
              isA<String>(),
              isNotEmpty,
              startsWith(r'SpinifyMetrics$Channel{'),
              endsWith('}'),
            ));
        expect(m.toJson, returnsNormally);
      });
    });
  });
}
