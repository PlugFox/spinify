import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:spinify/spinify.dart';
import 'package:spinifybenchmark/src/constant.dart';

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

  /// Number of bytes sent.
  int get sentBytes;

  /// Number of received messages.
  int get received;

  /// Number of bytes received.
  int get receivedBytes;

  /// Number of failed messages.
  int get failed;

  /// Total number of messages to send/receive.
  int get total;

  /// Progress of the benchmark in percent.
  int get progress;

  /// Duration of the benchmark in milliseconds.
  int get duration;

  /// Number of messages per second.
  int get messagePerSecond;

  /// Number of bytes per second.
  int get bytesPerSecond;

  /// Start the benchmark.
  Future<void> start({void Function(Object error)? onError});

  /// Dispose of the controller.
  void dispose();
}

abstract base class BenchmarkControllerBase
    with ChangeNotifier
    implements IBenchmarkController {
  Future<String> _getToken() => Future<String>.value(SpinifyJWT(
        sub: '1',
        exp: DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch,
        iss: 'benchmark',
        aud: 'benchmark',
      ).encode(tokenHmacSecretKey));

  @override
  final ValueNotifier<Library> library =
      ValueNotifier<Library>(Library.spinify);

  @override
  final TextEditingController endpoint =
      TextEditingController(text: defaultEndpoint);

  @override
  final ValueNotifier<int> payloadSize = ValueNotifier<int>(255 * 25);

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
  int get sentBytes => _sentBytes;
  int _sentBytes = 0;

  @override
  int get received => _received;
  int _received = 0;

  @override
  int get receivedBytes => _receivedBytes;
  int _receivedBytes = 0;

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
  int get messagePerSecond => _messagePerSecond;
  int _messagePerSecond = 0;

  @override
  int get bytesPerSecond => _bytesPerSecond;
  int _bytesPerSecond = 0;

  @override
  void dispose() {
    endpoint.dispose();
    super.dispose();
  }
}

base mixin SpinifyBenchmark on BenchmarkControllerBase {
  Future<void> startSpinify({void Function(Object error)? onError}) async {
    // 65510 bytes
    final payload =
        List<int>.generate(payloadSize.value, (index) => index % 256);
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
      pump('Connecting to centrifugo');
      client = Spinify(config: SpinifyConfig(getToken: _getToken));
      await client.connect(endpoint.text);
      if (!client.state.isConnected) throw Exception('Failed to connect');
      pump('Connected to ${endpoint.text}');
    } on Object catch (e) {
      pump('Failed to connect');
      onError?.call(e);
      stopwatch.stop();
      isRunning.value = false;
      return;
    }

    _total = messageCount.value;
    SpinifyClientSubscription subscription;
    StreamSubscription<SpinifyPublication>? streamSubscription;
    Completer<void>? completer;
    try {
      _pending = _sent = _received = _failed = _duration = 0;
      pump('Subscribing to channel "benchmark"');
      subscription = client.newSubscription('benchmark#1');
      await subscription.subscribe();
      if (!subscription.state.isSubscribed)
        throw Exception('Failed to subscribe to channel "benchmark"');
      streamSubscription = subscription.stream.publication().listen((event) {
        if (event.data.length == payload.length) {
          _received++;
          _receivedBytes += payload.length;
        } else {
          _failed++;
        }
        _duration = stopwatch.elapsedMilliseconds;
        completer?.complete();
      });
      for (var i = 0; i < _total; i++) {
        try {
          _pending++;
          pump('Sending message $i');
          completer = Completer<void>();
          await subscription.publish(payload);
          _sent++;
          _sentBytes += payload.length;
          pump('Sent message $i');
          await completer.future.timeout(const Duration(seconds: 5));
          pump('Received message $i');
        } on Object catch (e) {
          _failed++;
          onError?.call(e);
          pump('Failed to send message $i');
        } finally {
          _pending--;
          if (stopwatch.elapsed.inMilliseconds case int ms when ms > 0) {
            _messagePerSecond = (_sent + _received) * 1000 ~/ ms;
            _bytesPerSecond = (_sentBytes + _receivedBytes) * 1000 ~/ ms;
          }
        }
      }
      pump('Unsubscribing from channel "benchmark"');
      if (subscription.state.isSubscribed) await subscription.unsubscribe();
      pump('Done');
    } on Object catch (e) {
      onError?.call(e);
      pump('Failed. $e');
      return;
    } finally {
      stopwatch.stop();
      isRunning.value = false;
      streamSubscription?.cancel().ignore();
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
