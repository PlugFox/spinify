@internal
import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart';

/// Async callback
typedef EventCallback = FutureOr<void> Function();

/// An event queue is a queue of [EventCallback]s that are executed in order.
class EventQueue implements Sink<EventCallback> {
  /// Creates a new event queue.
  EventQueue();
  final Queue<_EventQueueTask> _queue = Queue<_EventQueueTask>();
  Future<void>? _processing;

  /// Returns `true` if the queue is closed.
  bool get isClosed => _closed;
  bool _closed = false;

  @override
  Future<void> add(EventCallback event) {
    if (_closed) {
      throw StateError('EventQueue is closed');
    }
    final task = _EventQueueTask(event);
    _queue.add(task);
    _start();
    return task.future;
  }

  @override
  Future<void> close({bool force = false}) async {
    if (_closed) return;
    _closed = true;
    if (force) {
      for (final task in _queue) {
        task.reject(
          StateError('OctopusStateQueue is closed'),
          StackTrace.current,
        );
      }
      _queue.clear();
    } else {
      await _processing;
    }
  }

  Future<void> _start() {
    final processing = _processing;
    if (processing != null) {
      return processing;
    }
    return _processing = Future.doWhile(() async {
      if (_queue.isEmpty) {
        _processing = null;
        return false;
      }
      try {
        await _queue.removeFirst()();
      } on Object catch (_, __) {/* ignore */} // coverage:ignore-line
      return true;
    });
  }
}

class _EventQueueTask {
  _EventQueueTask(EventCallback event)
      : _fn = event,
        _completer = Completer<void>();

  final EventCallback _fn;
  final Completer<void> _completer;

  Future<void> get future => _completer.future;

  /// Execute the task.
  Future<void> call() async {
    try {
      if (_completer.isCompleted) return;
      await _fn();
      if (_completer.isCompleted) return;
      _completer.complete();
    } on Object catch (error, stackTrace) {
      _completer.completeError(error, stackTrace); // coverage:ignore-line
    }
  }

  /// Reject the task with an error.
  void reject(Object error, [StackTrace? stackTrace]) {
    if (_completer.isCompleted) return; // coverage:ignore-line
    _completer.completeError(error, stackTrace);
  }
}
