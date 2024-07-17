// ignore_for_file: avoid_print

import 'package:spinify/spinify.dart';
import 'package:test/test.dart';

extension type _SpinifyChannelEventView(SpinifyChannelEvent event) {}

const $url = String.fromEnvironment('TEST_URL',
    defaultValue: 'ws://localhost:8000/connection/websocket');

const _enablePrint =
    bool.fromEnvironment('TEST_ENABLE_PRINT', defaultValue: false);

final $logBuffer = SpinifyLogBuffer(size: 100);

void _loggerPrint(SpinifyLogLevel level, String event, String message,
        Map<String, Object?> context) =>
    print('[$event] $message');

SpinifyReply? _$prevPeply; // ignore: unused_local_variable
void _loggerCheckReply(SpinifyLogLevel level, String event, String message,
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
    if (_$prevPeply != null) {
      expect(() => reply == _$prevPeply, returnsNormally);
      expect(reply.compareTo(_$prevPeply!), isNonNegative);
    }
    _$prevPeply = reply;
  }
}

SpinifyChannelEvent? _$prevEvent;
void _loggerCheckEvents(SpinifyLogLevel level, String event, String message,
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
    if (_$prevEvent != null) {
      expect(event.compareTo(_$prevEvent!), isNonNegative);
    }
    _$prevEvent = event;
  }
}

void _logger(SpinifyLogLevel level, String event, String message,
    Map<String, Object?> context) {
  final args = [level, event, message, context];
  if (_enablePrint) Function.apply(_loggerPrint, args);
  Function.apply($logBuffer.add, args);
  Function.apply(_loggerCheckReply, args);
  Function.apply(_loggerCheckEvents, args);
}

ISpinify $createClient() => Spinify(
      config: SpinifyConfig(
        connectionRetryInterval: (
          min: const Duration(milliseconds: 50),
          max: const Duration(milliseconds: 150),
        ),
        logger: _logger,
      ),
    );
