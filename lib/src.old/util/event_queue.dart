import 'dart:async';
import 'dart:collection';

import 'logger.dart';

/// Event Queue
final class SpinifyEventQueue {
  /// Create a new instance of [SpinifyEventQueue].
  SpinifyEventQueue();

  final DoubleLinkedQueue<SpinifyTask<Object?>> _queue =
      DoubleLinkedQueue<SpinifyTask<Object?>>();
  Future<void>? _processing;
  bool _isClosed = false;

  /// Push it at the end of the queue.
  Future<T> push<T>(String id, FutureOr<T> Function() fn) {
    final task = SpinifyTask<T>(id, fn);
    _queue.add(task);
    _exec();
    return task.future;
  }

  /// Mark the queue as closed.
  /// The queue will be processed until it's empty.
  /// But all new and current events will be rejected with [WSClientClosed].
  FutureOr<void> close() async {
    _isClosed = true;
    await _processing;
  }

  /// Execute the queue.
  void _exec() => _processing ??= Future.doWhile(() async {
        final event = _queue.first;
        try {
          if (_isClosed) {
            event.reject(
              StateError('Event Queue already closed'),
              StackTrace.current,
            );
          } else {
            await event();
          }
        } on Object catch (error, stackTrace) {
          warning(
            error,
            stackTrace,
            'Error while processing event "${event.id}"',
          );
          Future<void>.sync(() => event.reject(error, stackTrace)).ignore();
        }
        if (_queue.isEmpty) {
          _processing = null;
          return false;
        } else {
          _queue.removeFirst();
          final isEmpty = _queue.isEmpty;
          if (isEmpty) _processing = null;
          return !isEmpty;
        }
      });
}

/// Task for the [SpinifyEventQueue].
class SpinifyTask<T> {
  /// Create a new instance of [SpinifyTask].
  SpinifyTask(this.id, FutureOr<T> Function() fn)
      : _fn = fn,
        _completer = Completer<T>();

  final Completer<T> _completer;

  /// Unique identifier for the task.
  final String id;

  final FutureOr<T> Function() _fn;

  /// Future of the task.
  Future<T> get future => _completer.future;

  /// Execute the task.
  FutureOr<T> call() async {
    final result = await _fn();
    if (!_completer.isCompleted) {
      _completer.complete(result);
    }
    return result;
  }

  /// Reject the task with [error] and [stackTrace].
  void reject(Object error, [StackTrace? stackTrace]) {
    if (_completer.isCompleted) return; // coverage:ignore-line
    _completer.completeError(error, stackTrace);
  }
}
