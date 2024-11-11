import 'dart:async';

import 'package:meta/meta.dart';

/// A request for a mutex lock.
class _Mutex$Request {
  /// Creates a new mutex request.
  _Mutex$Request._(Completer<void> completer)
      : _completer = completer,
        future = completer.future;

  /// Creates a new mutex request with a synchronous completer.
  factory _Mutex$Request.sync() => _Mutex$Request._(Completer<void>.sync());

  final Completer<void> _completer; // The completer for the request.
  void release() => _completer.complete(); // Releases the lock.
  final Future<void> future; // The future for the request.
  _Mutex$Request? prev; // The previous request in the chain.
}

/// A mutual exclusion lock.
@internal
class Mutex {
  /// Creates a new mutex.
  Mutex();

  _Mutex$Request? _last; // The last requested block
  _Mutex$Request? _current; // The first and current running block
  int _locks = 0; // The number of locks currently held

  /// The number of locks currently held.
  int get locks => _locks;

  /// The list of pending locks.
  List<Future<void>> get pending {
    final pending = List<Future<void>>.filled(_locks, Future<void>.value(),
        growable: false);
    for (var i = _locks - 1, request = _last;
        i >= 0;
        i--, request = request?.prev) {
      final future = request?.future;
      if (future != null)
        pending[i] = future;
      else
        assert(false, 'Invalid lock state'); // coverage:ignore-line
    }
    return pending;
  }

  /// Protects a callback with the mutex.
  Future<T> protect<T>(Future<T> Function() callback) async {
    await lock();
    try {
      return await callback();
    } finally {
      unlock();
    }
  }

  /// Locks the mutex.
  Future<void> lock() async {
    _locks++;
    final prev = _last;
    final current = _last = _Mutex$Request.sync()..prev = prev;
    // Wait for the previous lock to be released.
    if (prev != null) await prev.future;
    _current = current..prev = null; // Set the current lock.
  }

  /// Unlocks the mutex.
  void unlock() {
    final current = _current;
    if (current == null) return;
    _locks--;
    _current = null;
    current.release();
  }
}
