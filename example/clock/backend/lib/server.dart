library;

import 'dart:async';
import 'dart:convert';

import 'package:l/l.dart';
import 'package:spinify/spinify.dart';

void runServer() => l.capture(
      () => runZonedGuarded<void>(
        () async {
          const url = 'ws://centrifugo:8000/connection/websocket';
          final spinify = Spinify.connect(
            url,
            config: SpinifyConfig(
              client: (name: 'Server', version: '1.0.0'),
              logger: (level, event, message, context) => l.log(
                LogMessage.verbose(
                  timestamp: DateTime.now(),
                  level: switch (level) {
                    0 => const LogLevel.debug(),
                    1 => const LogLevel.vvvv(),
                    2 => const LogLevel.vvv(),
                    3 => const LogLevel.info(),
                    4 => const LogLevel.warning(),
                    5 => const LogLevel.error(),
                    6 => const LogLevel.shout(),
                    _ => const LogLevel.info(),
                  },
                  message: message,
                  context: context,
                ),
              ),
            ),
          );
          final subscription =
              spinify.newSubscription('clock', subscribe: true);
          final encoder = const JsonEncoder().fuse(const Utf8Encoder());
          Timer.periodic(const Duration(seconds: 1), (timer) {
            // If not connected - try to reconnect
            if (spinify.state.isDisconnected) {
              spinify.connect(url);
              return;
            }

            // If the subscription is not active, do nothing
            if (!subscription.state.isSubscribed) return;

            // Publish the current time
            final now = DateTime.now();
            subscription.publish(
              encoder.convert(
                <String, Object?>{
                  'hour': now.hour,
                  'minute': now.minute,
                  'second': now.second,
                },
              ),
            );
          });
        },
        l.e,
      ),
      LogOptions(
        outputInRelease: true,
        handlePrint: true,
        printColors: false,
        output: LogOutput.platform,
        overrideOutput: (message) => '[${message.level}] ${message.message}',
        messageFormatting: (message) => message,
      ),
    );
