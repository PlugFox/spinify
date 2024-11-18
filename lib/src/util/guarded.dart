import 'dart:async';

import 'package:meta/meta.dart';

/// Runs the given [callback] in a zone that catches uncaught errors and
/// forwards them to the returned future.
///
/// [ignore] is used to ignore the errors and not throw them.
@internal
Future<void> asyncGuarded(
  Future<void> Function() callback, {
  bool ignore = false,
}) async {
  Object? $error;
  StackTrace? $stackTrace;

  await runZonedGuarded<Future<void>>(
    () async {
      try {
        await callback();
      } on Object catch (error, stackTrace) {
        $error = error;
        $stackTrace = stackTrace;
      }
    },
    (error, stackTrace) {
      // This should never be called.
      //debugger();
      $error = error;
      $stackTrace = stackTrace;
    },
  );

  final error = $error;
  if (error == null) return;
  if (ignore) return;
  Error.throwWithStackTrace(error, $stackTrace ?? StackTrace.empty);
}

/// Runs the given [callback] in a zone that catches uncaught errors and
/// rethrows them.
///
/// [ignore] is used to ignore the errors and not throw them.
@internal
void guarded(
  void Function() callback, {
  bool ignore = false,
}) {
  Object? $error;
  StackTrace? $stackTrace;

  runZonedGuarded<void>(
    () {
      try {
        callback();
      } on Object catch (error, stackTrace) {
        $error = error;
        $stackTrace = stackTrace;
      }
    },
    (error, stackTrace) {
      // This should never be called.
      //debugger();
      $error = error;
      $stackTrace = stackTrace;
    },
  );

  final error = $error;
  if (error == null) return;
  if (ignore) return;
  Error.throwWithStackTrace(error, $stackTrace ?? StackTrace.empty);
}
