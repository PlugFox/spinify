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

  /// Creates a new mutex request with a asynchronous completer.
  //factory _Mutex$Request.async() => _Mutex$Request._(Completer<void>());

  final Completer<void> _completer; // The completer for the request.
  bool get isCompleted => _completer.isCompleted; // Is completed?
  bool get isNotCompleted => !_completer.isCompleted; // Is not completed?
  void release() => _completer.complete(); // Releases the lock.
  final Future<void> future; // The future for the request.
  _Mutex$Request? prev; // The previous request in the chain.
}

/// A mutual exclusion lock.
@internal
abstract interface class IMutex {
  /// The number of locks currently held.
  int get locks;

  /// The list of pending locks.
  List<Future<void>> get pending;

  /// Protects a callback with the mutex.
  Future<T> protect<T>(Future<T> Function() callback);

  /// Locks the mutex.
  Future<void> lock();

  /// Unlocks the mutex.
  void unlock();

  /// Waits for the last lock at the current moment to be released.
  /// This method do not add a new lock.
  Future<void> wait();
}

/// A mutual exclusion lock.
@internal
class MutexImpl implements IMutex {
  /// Creates a new mutex.
  MutexImpl();

  _Mutex$Request? _last; // The last requested block
  _Mutex$Request? _current; // The first and current running block
  int _locks = 0; // The number of locks currently held

  /// The number of locks currently held.
  @override
  int get locks => _locks;

  /// The list of pending locks.
  @override
  List<Future<void>> get pending {
    final pending = List<Future<void>>.filled(
      _locks,
      Future<void>.value(),
      growable: false,
    );
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
  @override
  Future<T> protect<T>(Future<T> Function() callback) async {
    await lock();
    try {
      return await callback();
    } finally {
      unlock();
    }
  }

  /// Locks the mutex.
  @override
  Future<void> lock() async {
    _locks++;
    final prev = _last;
    final current = _last = _Mutex$Request.sync()..prev = prev;
    // Wait for the previous lock to be released.
    if (prev != null && prev.isNotCompleted) await prev.future;
    _current = current..prev = null; // Set the current lock.
  }

  /// Unlocks the mutex.
  @override
  void unlock() {
    final current = _current;
    if (current == null) return;
    _locks--;
    _current = null;
    current.release();
  }

  @override
  Future<void> wait() async {
    final last = _last;
    if (last != null) await last.future;
  }
}

/// A fake mutex that does nothing.
@internal
class MutexDisabled implements IMutex {
  MutexDisabled();

  static final Future<void> _future = Future<void>.value();

  @override
  int get locks => 0;

  @override
  List<Future<void>> get pending => const [];

  @override
  Future<T> protect<T>(Future<T> Function() callback) => callback();

  @override
  Future<void> lock() => _future;

  @override
  void unlock() {}

  @override
  Future<void> wait() => _future;
}
