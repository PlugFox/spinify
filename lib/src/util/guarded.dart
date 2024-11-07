import 'dart:async';
import 'dart:developer';

import 'package:meta/meta.dart';

/// Runs the given [callback] in a zone that catches uncaught errors and
/// forwards them to the returned future.
///
/// [ignore] is used to ignore the errors and not throw them.
@internal
Future<void> asyncGuarded(
  Future<void> Function() callback, {
  bool ignore = false,
}) {
  final completer = Completer<void>.sync();

  var completed = false;

  void complete() {
    if (completed) return;
    completed = true;
    completer.complete();
  }

  void completeError(Object error, StackTrace stackTrace) {
    if (completed) return;
    completed = true;
    if (ignore) {
      completer.complete();
    } else {
      completer.completeError(error, stackTrace);
    }
  }

  runZonedGuarded<Future<void>>(
    () async {
      try {
        await callback();
        complete();
      } on Object catch (error, stackTrace) {
        completeError(error, stackTrace);
      }
    },
    // ignore: unnecessary_lambdas
    (error, stackTrace) {
      // This should never be called.
      debugger();
      completeError(error, stackTrace);
    },
  );

  return completer.future;
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
      debugger();
      $error = error;
      $stackTrace = stackTrace;
    },
  );

  final error = $error;
  final stackTrace = $stackTrace;
  if (error == null) return;
  if (ignore) return;
  Error.throwWithStackTrace(error, stackTrace ?? StackTrace.empty);
}
