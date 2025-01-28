library;

import 'dart:async';

import 'package:l/l.dart';
import 'package:spinify_clock_frontend/src/clock_layer.dart';
import 'package:spinify_clock_frontend/src/engine.dart';

void runSite() => l.capture(
      () => runZonedGuarded<void>(
        () {
          final layer = ClockLayer()..setTime(DateTime.now());
          final _ = RenderingEngine.instance
            ..addLayer(layer)
            ..start();

          Timer.periodic(const Duration(seconds: 1), (timer) {
            layer.setTime(DateTime.now());
          });

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
