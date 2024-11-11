// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:collection';

import 'package:benchmark_harness/benchmark_harness.dart';

void main() => Future<void>(() async {
      final baseUs = await _WithoutMutex().measure();
      final scores = await Stream<AsyncBenchmarkBase>.fromIterable(
        <AsyncBenchmarkBase>[
          _MutexCompleterList(),
          _MutexCompleterQueue(),
          _MutexCompleterLinkedList(),
        ],
      )
          .asyncMap((benchmark) async =>
              (name: benchmark.name, score: await benchmark.measure() - baseUs))
          .toList();
      scores.sort((a, b) => a.score.compareTo(b.score));
      for (final score in scores) {
        print('${score.name}: ${score.score} us.');
      }
    });

class _Base extends AsyncBenchmarkBase {
  _Base(super.name);

  int _counter = 0;

  @override
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
  Future<void> teardown() async {
    if (_counter == 0) throw StateError('Counter mismatch');
    return super.teardown();
  }
}

class _WithoutMutex extends _Base {
  _WithoutMutex() : super('Without mutex');

  @override
  Future<void> run() => Future<void>.delayed(Duration.zero, () {
        final value = _counter;
        _counter = value + 1;
      });
}

class _MutexCompleterList extends _Base {
  _MutexCompleterList() : super('Completers list');

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

class _MutexCompleterLinkedList extends _Base {
  _MutexCompleterLinkedList() : super('Completers linked list');

  var _nodes = _Node(Future<void>.value());

  @override
  Future<void> run() async {
    final prev = _nodes;
    final completer = Completer<void>.sync();
    final next = _nodes = _Node(completer.future)..next;
    await prev.future;
    final value = _counter;
    await Future<void>.delayed(Duration.zero);
    _counter = value + 1;
    //if (_counter < 50) print('$value -> $_counter');
    next.next = null;
    completer.complete();
  }
}

class _Node {
  _Node(this.future);
  final Future<void> future;
  _Node? next;
}

class _MutexCompleterQueue extends _Base {
  _MutexCompleterQueue() : super('Completers queue');

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
