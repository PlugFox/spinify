import 'dart:async';
import 'dart:developer' as developer;

import 'package:meta/meta.dart';

/// Constants used to debug the Centrifuge client.
/// --dart-define=dev.plugfox.ws.debug=true
/// {@nodoc}
@internal
bool get $enableLogging =>
    const bool.fromEnvironment(
      'dev.plugfox.centrifuge.log',
      defaultValue: false,
    ) ||
    Zone.current[#dev.plugfox.centrifuge.log] == true;

/// Tracing information
/// {@nodoc}
@internal
final void Function(Object? message) fine = _logAll('FINE', 500);

/// Static configuration messages
/// {@nodoc}
@internal
final void Function(Object? message) config = _logAll('CONF', 700);

/// Iformational messages
/// {@nodoc}
@internal
final void Function(Object? message) info = _logAll('INFO', 800);

/// Potential problems
/// {@nodoc}
@internal
final void Function(Object exception, [StackTrace? stackTrace, String? reason])
    warning = _logAll('WARN', 900);

/// Serious failures
/// {@nodoc}
@internal
final void Function(Object error, [StackTrace stackTrace, String? reason])
    severe = _logAll('ERR!', 1000);

/// {@nodoc}
void Function(
  Object? message, [
  StackTrace? stackTrace,
  String? reason,
]) _logAll(String prefix, int level) => (message, [stackTrace, reason]) {
      // coverage:ignore-start
      if (!$enableLogging) return;
      developer.log(
        reason ?? message?.toString() ?? '',
        level: level,
        name: 'centrifuge',
        error: message is Exception || message is Error ? message : null,
        stackTrace: stackTrace,
      );
      // coverage:ignore-end
    };
