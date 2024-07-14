import 'dart:developer' as dev;

import 'package:meta/meta.dart';

// TODO(plugfox): Impliment rotating log buffer

/// Constants used to debug the Spinify client.
/// --dart-define=dev.plugfox.spinify.debug=true
const bool $enableLogging = bool.fromEnvironment(
  'dev.plugfox.spinify.log',
  defaultValue: false,
);

/// Tracing information
@internal
final void Function(Object? message) fine = _logAll('FINE', 500);

/// Static configuration messages
@internal
final void Function(Object? message) config = _logAll('CONF', 700);

/// Iformational messages
@internal
final void Function(Object? message) info = _logAll('INFO', 800);

/// Potential problems
@internal
final void Function(Object exception, [StackTrace? stackTrace, String? reason])
    warning = _logAll('WARN', 900);

/// Serious failures
@internal
final void Function(Object error, [StackTrace stackTrace, String? reason])
    severe = _logAll('ERR!', 1000);

void Function(
  Object? message, [
  StackTrace? stackTrace,
  String? reason,
]) _logAll(String prefix, int level) => (message, [stackTrace, reason]) {
      // coverage:ignore-start
      if (!$enableLogging) return;
      dev.log(
        reason ?? message?.toString() ?? '',
        level: level,
        name: 'spinify',
        error: message is Exception || message is Error ? message : null,
        stackTrace: stackTrace,
      );
      // coverage:ignore-end
    };
