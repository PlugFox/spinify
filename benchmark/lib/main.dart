import 'dart:async';

import 'package:flutter/material.dart';
import 'package:l/l.dart';
import 'package:spinifybenchmark/src/benchmark_app.dart';

void main() => _appZone(() async {
      runApp(const BenchmarkApp());
    });

/// Catch all application errors and logs.
void _appZone(FutureOr<void> Function() fn) => l.capture<void>(
      () => runZonedGuarded<void>(
        () => fn(),
        l.e,
      ),
      const LogOptions(
        handlePrint: true,
        messageFormatting: _messageFormatting,
        outputInRelease: false,
        printColors: true,
      ),
    );

/// Formats the log message.
Object _messageFormatting(LogMessage log) =>
    '${_timeFormat(log.timestamp)} | ${log.message}';

/// Formats the time.
String _timeFormat(DateTime time) =>
    '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
