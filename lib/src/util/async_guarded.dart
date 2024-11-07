import 'dart:async';

import 'package:meta/meta.dart';

/// Runs the given [callback] in a zone that catches uncaught errors and
/// forwards them to the returned future.
@internal
Future<void> asyncGuarded(Future<void> Function() callback) {
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
    completer.completeError(error, stackTrace);
  }

  runZonedGuarded<void>(
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
      // This is called when an error is thrown outside of the `try` block.
      //debugger();
      completeError(error, stackTrace);
    },
  );

  return completer.future;
}
