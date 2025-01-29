library;

import 'dart:async';
import 'dart:convert';

import 'package:l/l.dart';
import 'package:spinify/spinify.dart';
import 'package:spinify_clock_frontend/src/clock_layer.dart';
import 'package:spinify_clock_frontend/src/engine.dart';

void runSite() => l.capture(
      () => runZonedGuarded<void>(
        () async {
          final layer = ClockLayer();
          final _ = RenderingEngine.instance
            ..addLayer(layer)
            ..start();

          final spinify = Spinify.connect(
            'ws://127.0.0.1:3082/connection/websocket',
            config: SpinifyConfig(
              client: (name: 'Website', version: '1.0.0'),
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
          final decoder = const Utf8Decoder()
              .fuse(const JsonDecoder())
              .cast<List<int>, Map<String, Object?>>();
          subscription.stream.publication().listen(
            (event) {
              final update = decoder.convert(event.data);
              if (update
                  case {
                    'hour': int hour,
                    'minute': int minute,
                    'second': int second
                  }) {
                layer.setTime(
                  hour: hour,
                  minute: minute,
                  second: second,
                );
              }
            },
            cancelOnError: false,
          );
          l.i('Engine started');
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
