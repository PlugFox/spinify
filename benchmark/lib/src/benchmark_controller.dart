import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:spinify/spinify.dart';

enum Library { spinify, centrifuge }

abstract interface class IBenchmarkController implements Listenable {
  /// Library to use for the benchmark.
  abstract final ValueNotifier<Library> library;

  /// WebSocket endpoint to connect to.
  abstract final TextEditingController endpoint;

  /// Size in bytes of the payload to send/receive.
  abstract final ValueNotifier<int> payloadSize;

  /// Number of messages to send/receive.
  abstract final ValueNotifier<int> messageCount;

  /// Whether the benchmark is running.
  abstract final ValueListenable<bool> isRunning;

  /// Status of the benchmark.
  String get status;

  /// Number of pending messages.
  int get pending;

  /// Number of sent messages.
  int get sent;

  /// Number of received messages.
  int get received;

  /// Number of failed messages.
  int get failed;

  /// Total number of messages to send/receive.
  int get total;

  /// Progress of the benchmark in percent.
  int get progress;

  /// Duration of the benchmark in milliseconds.
  int get duration;

  /// Start the benchmark.
  Future<void> start({void Function(Object error)? onError});

  /// Dispose of the controller.
  void dispose();
}

abstract base class BenchmarkControllerBase
    with ChangeNotifier
    implements IBenchmarkController {
  @override
  final ValueNotifier<Library> library =
      ValueNotifier<Library>(Library.spinify);

  @override
  final TextEditingController endpoint =
      TextEditingController(text: 'ws://localhost:8000/connection/websocket');

  @override
  final ValueNotifier<int> payloadSize = ValueNotifier<int>(1024 * 1024);

  @override
  final ValueNotifier<int> messageCount = ValueNotifier<int>(1000);

  @override
  final ValueNotifier<bool> isRunning = ValueNotifier<bool>(false);

  @override
  String get status => _status;
  String _status = '';

  @override
  int get pending => _pending;
  int _pending = 0;

  @override
  int get sent => _sent;
  int _sent = 0;

  @override
  int get received => _received;
  int _received = 0;

  @override
  int get failed => _failed;
  int _failed = 0;

  @override
  int get total => _total;
  int _total = 0;

  @override
  int get progress =>
      _total == 0 ? 0 : (((_received + _failed) * 100) ~/ _total).clamp(0, 100);

  @override
  int get duration => _duration;
  int _duration = 0;

  @override
  void dispose() {
    endpoint.dispose();
    super.dispose();
  }
}

base mixin SpinifyBenchmark on BenchmarkControllerBase {
  Future<void> startSpinify({void Function(Object error)? onError}) async {
    _duration = 0;
    isRunning.value = true;
    final stopwatch = Stopwatch()..start();
    void pump(String message) {
      _status = message;
      _duration = stopwatch.elapsedMilliseconds;
      notifyListeners();
    }

    final Spinify client;
    try {
      pump('Connecting to ${endpoint.text}...');
      client = Spinify();
      await client.connect(endpoint.text);
      pump('Connected to ${endpoint.text}.');
    } on Object catch (e) {
      pump('Failed to connect to ${endpoint.text}. $e');
      onError?.call(e);
      stopwatch.stop();
      isRunning.value = false;
      return;
    }

    final payload =
        List<int>.generate(payloadSize.value, (index) => index % 256);

    _total = messageCount.value;
    SpinifyClientSubscription subscription;
    StreamSubscription<SpinifyPublication>? streamSubscription;
    Completer<void>? completer;
    try {
      _pending = _sent = _received = _failed = _duration = 0;
      pump('Subscribing to channel "benchmark"...');
      subscription = client.newSubscription('benchmark');
      await subscription.subscribe();
      streamSubscription = subscription.stream.publication().listen((event) {
        if (event.data.length == payload.length) {
          _received++;
        } else {
          _failed++;
        }
        _duration = stopwatch.elapsedMilliseconds;
        completer?.complete();
      });
      for (var i = 0; i < _total; i++) {
        try {
          _pending++;
          pump('Sending message $i...');
          completer = Completer<void>();
          await client.publish('benchmark', payload);
          _sent++;
          pump('Sent message $i.');
          await completer.future.timeout(const Duration(seconds: 5));
          pump('Received message $i.');
        } on Object catch (e) {
          _failed++;
          onError?.call(e);
          pump('Failed to send message $i.');
        }
      }
      pump('Unsubscribing from channel "benchmark"...');
      await client.removeSubscription(subscription);
      pump('Disconnecting from ${endpoint.text}...');
      await client.disconnect();
      pump('Done.');
    } on Object catch (e) {
      onError?.call(e);
      pump('Failed. $e');
      isRunning.value = false;
      return;
    } finally {
      streamSubscription?.cancel().ignore();
      stopwatch.stop();
      client.disconnect().ignore();
    }
  }
}

base mixin CentrifugeBenchmark on BenchmarkControllerBase {
  Future<void> startCentrifuge({void Function(Object error)? onError}) async {}
}

final class BenchmarkControllerImpl extends BenchmarkControllerBase
    with SpinifyBenchmark, CentrifugeBenchmark {
  @override
  Future<void> start({void Function(Object error)? onError}) {
    switch (library.value) {
      case Library.spinify:
        return startSpinify(onError: onError);
      case Library.centrifuge:
        return startCentrifuge(onError: onError);
    }
  }
}
