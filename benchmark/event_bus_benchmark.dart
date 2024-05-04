import 'dart:async';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:spinify/spinify.dart';
import 'package:spinify/src/event_bus.dart';

void main() => Future<void>(() async {
      await SpinifyEventBus$Benchmark().report();
    });

enum _BenchmarkEvent { fake }

class SpinifyEventBus$Benchmark extends AsyncBenchmarkBase {
  SpinifyEventBus$Benchmark() : super(r'SpinifyEventBus$Benchmark');

  late Spinify _client;
  late ISpinifyEventBus$Bucket _bucket;
  int _pushed = 0;
  int _received = 0;

  /// Not measured setup code executed prior to the benchmark runs.
  @override
  Future<void> setup() async {
    await super.setup();
    _client = Spinify();
    _bucket = SpinifyEventBus.instance.getBucket(_client);
    _bucket.subscribe(_BenchmarkEvent.fake, (_) async => _received++);
  }

  @override
  Future<void> run() async {
    _pushed++;
    await _bucket.push(_BenchmarkEvent.fake);
  }

  @override
  Future<void> teardown() async {
    await _client.close();
    if (_pushed != _received) {
      throw StateError('Pushed $_pushed events, but received $_received');
    }
    await super.teardown();
  }
}
