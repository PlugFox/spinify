/*
 * Mutex benchmark
 * https://gist.github.com/PlugFox/264d59a37d02dd06a7123ef19ee8537d
 * https://dartpad.dev?id=264d59a37d02dd06a7123ef19ee8537d
 * Mike Matiunin <plugfox@gmail.com>, 11 November 2024
 */

import 'dart:async';
import 'dart:collection';
import 'dart:isolate';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:meta/meta.dart';

void main() => Future<void>(() async {
      //final baseUs = await _WithoutMutex().measure();
      final benchmarks = <AsyncBenchmarkBase Function()>[
        _WithoutMutex.new,
        _MutexList.new,
        _MutexQueue.new,
        _MutexLinked.new,
        _MutexLock.new,
        _MutexLast.new,
        _MutexWrap.new,
        _MutexEncapsulated.new,
      ];
      final results =
          await Stream<AsyncBenchmarkBase Function()>.fromIterable(benchmarks)
              .asyncMap(
                (constructor) async => await Isolate.run(
                  () async {
                    final benchmark = constructor();
                    return (
                      name: benchmark.name,
                      score: await benchmark.measure()
                    );
                  },
                ),
              )
              .toList();
      results.sort((a, b) => a.score.compareTo(b.score));
      final buffer = StringBuffer();
      for (final r in results) {
        buffer.writeln('${r.name.padLeft(12)} |'
            ' ${r.score.toStringAsPrecision(6).padRight(8)} us |'
            ' ${1000000 ~/ r.score} FPS');
      }
      print(buffer.toString()); // ignore: avoid_print
    });

class _Base extends AsyncBenchmarkBase {
  _Base(super.name);

  int _counter = 0;

  @override
  @mustCallSuper
  Future<void> setup() async {
    _counter = 0;
    return super.setup();
  }

  /// Measures the score for this benchmark by executing it repeatedly until
  /// time minimum has been reached.
  static Future<double> measureFor(
      Future<void> Function() f, int minimumMillis) async {
    final futures = List<Future<void>>.filled(100, Future<void>.value());
    final minimumMicros = minimumMillis * 1000;
    final watch = Stopwatch()..start();
    var iter = 0;
    var elapsed = 0;
    while (elapsed < minimumMicros) {
      for (var i = 0; i < 100; i++) {
        futures[i] = f();
        iter++;
      }
      await Future.wait<void>(futures);
      elapsed = watch.elapsedMicroseconds;
    }
    return elapsed / iter;
  }

  /// Measures the score for the benchmark and returns it.
  @override
  @mustCallSuper
  Future<double> measure() async {
    await setup();
    try {
      // Warmup for at least 100ms. Discard result.
      await measureFor(warmup, 100);
    } finally {
      await teardown();
    }
    await setup();
    try {
      // Run the benchmark for at least 2000ms.
      return await measureFor(exercise, 2000);
    } finally {
      await teardown();
    }
  }

  @override
  @mustCallSuper
  Future<void> teardown() async {
    if (_counter == 0) throw StateError('Counter mismatch');
    return super.teardown();
  }
}

class _WithoutMutex extends _Base {
  _WithoutMutex() : super('Without');

  @override
  Future<void> run() => Future<void>.delayed(Duration.zero, () {
        final value = _counter;
        _counter = value + 1;
      });
}

class _MutexList extends _Base {
  _MutexList() : super('List');

  final _list = <Future<void>>[Future<void>.value()];

  @override
  Future<void> run() async {
    final last = _list.last;
    final completer = Completer<void>.sync();
    _list.add(completer.future);
    await last;
    final value = _counter;
    await Future<void>.delayed(Duration.zero);
    _counter = value + 1;
    //if (_counter < 50) print('$value -> $_counter');
    unawaited(_list.removeAt(0));
    completer.complete();
  }
}

class _MutexLinked extends _Base {
  _MutexLinked() : super('Linked');

  _Mutex$Request? _node;

  @override
  Future<void> run() async {
    final prev = _node;
    final current = _node = _Mutex$Request.sync()..prev = prev;
    await prev?.future;
    final value = _counter;
    await Future<void>.delayed(Duration.zero);
    _counter = value + 1;
    //if (_counter < 50) print('$value -> $_counter');
    current.prev = null;
    if (identical(_node, current)) _node = null;
    current.release();
  }
}

class _MutexQueue extends _Base {
  _MutexQueue() : super('Queue');

  final _queue = Queue<Future<void>>()..add(Future<void>.value());

  @override
  Future<void> run() async {
    final last = _queue.last;
    final completer = Completer<void>.sync();
    _queue.add(completer.future);
    await last;
    final value = _counter;
    await Future<void>.delayed(Duration.zero);
    _counter = value + 1;
    //if (_counter < 50) print('$value -> $_counter');
    unawaited(_queue.removeFirst());
    completer.complete();
  }
}

class _MutexLast extends _Base {
  _MutexLast() : super('Last');

  Future<void>? _last; // The last running block

  @override
  Future<void> run() async {
    final prev = _last;
    final completer = Completer<void>.sync();
    final current = _last = completer.future;
    await prev;
    final value = _counter;
    await Future<void>.delayed(Duration.zero);
    _counter = value + 1;
    //if (_counter < 50) print('$value -> $_counter');
    if (identical(_last, current)) _last = null;
    completer.complete();
  }
}

class _MutexLock extends _Base {
  _MutexLock() : super('Lock');

  Future<void>? _last; // The last running block

  Future<void Function()> _lock() async {
    final prev = _last;
    final completer = Completer<void>.sync();
    final current = _last = completer.future;
    await prev;
    return () {
      if (identical(_last, current)) _last = null;
      completer.complete();
    };
  }

  @override
  Future<void> run() async {
    final unlock = await _lock();
    final value = _counter;
    await Future<void>.delayed(Duration.zero);
    _counter = value + 1;
    //if (_counter < 50) print('$value -> $_counter');
    unlock();
  }
}

class _MutexWrap extends _Base {
  _MutexWrap() : super('Wrap');

  Future<void>? _last; // The last running block

  Future<void> _wrap(Future<void> Function() fn) async {
    final prev = _last;
    final completer = Completer<void>.sync();
    final current = _last = completer.future;
    await prev;
    await fn();
    if (identical(_last, current)) _last = null;
    completer.complete();
  }

  @override
  Future<void> run() => _wrap(() async {
        final value = _counter;
        await Future<void>.delayed(Duration.zero);
        _counter = value + 1;
        //if (_counter < 50) print('$value -> $_counter');
      });
}

class _MutexEncapsulated extends _Base {
  _MutexEncapsulated() : super('Encapsulated');

  final _Mutex _m = _Mutex();

  @override
  Future<void> run() async {
    await _m.lock();
    try {
      final value = _counter;
      await Future<void>.delayed(Duration.zero);
      _counter = value + 1;
      //if (_counter < 50) print('$value -> $_counter');
    } finally {
      _m.unlock();
    }
  }

  @override
  @mustCallSuper
  Future<void> teardown() async {
    if (_m.locks != 0) throw StateError('Lock mismatch');
    return super.teardown();
  }
}

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
class _Mutex {
  /// Creates a new mutex.
  _Mutex();

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
        assert(false, 'Invalid lock state');
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
