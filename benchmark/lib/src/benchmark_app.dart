import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:spinify/spinify.dart';

class BenchmarkApp extends StatefulWidget {
  const BenchmarkApp({super.key});

  @override
  State<BenchmarkApp> createState() => _BenchmarkAppState();
}

class _BenchmarkAppState extends State<BenchmarkApp> {
  final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(
      PlatformDispatcher.instance.platformBrightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light);

  @override
  void initState() {
    super.initState();
    themeMode.addListener(_onChanged);
  }

  @override
  void dispose() {
    themeMode.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  void toggleTheme() => themeMode.value = switch (themeMode.value) {
        ThemeMode.dark => ThemeMode.light,
        ThemeMode.light || _ => ThemeMode.dark,
      };

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Benchmark',
        themeMode: themeMode.value,
        theme: switch (themeMode.value) {
          ThemeMode.dark => ThemeData.dark(),
          ThemeMode.light || _ => ThemeData.light(),
        },
        home: _BenchmarkScaffold(
          themeMode: themeMode,
        ),
      );
}

enum Library { spinify, centrifuge }

abstract base class BenchmarkControllerBase with ChangeNotifier {
  /// Library to use for the benchmark.
  final ValueNotifier<Library> library =
      ValueNotifier<Library>(Library.spinify);

  /// WebSocket endpoint to connect to.
  final TextEditingController endpoint =
      TextEditingController(text: 'ws://localhost:8000/connection/websocket');

  /// Size in bytes of the payload to send/receive.
  final ValueNotifier<int> payloadSize = ValueNotifier<int>(1024 * 1024);

  /// Number of messages to send/receive.
  final ValueNotifier<int> messageCount = ValueNotifier<int>(1000);

  /// Number of pending messages.
  int get pending => _pending;
  int _pending = 0;

  /// Number of sent messages.
  int get sent => _sent;
  int _sent = 0;

  /// Number of received messages.
  int get received => _received;
  int _received = 0;

  /// Number of failed messages.
  int get failed => _failed;
  int _failed = 0;

  /// Total number of messages to send/receive.
  int get total => _total;
  int _total = 0;

  /// Progress of the benchmark in percent.
  int get progress =>
      _total == 0 ? 0 : (((_received + _failed) * 100) ~/ _total).clamp(0, 100);

  /// Duration of the benchmark in milliseconds.
  int get duration => _duration;
  int _duration = 0;

  /// Start the benchmark.
  Future<void> start();

  @override
  void dispose() {
    endpoint.dispose();
    super.dispose();
  }
}

base mixin SpinifyBenchmark on BenchmarkControllerBase {
  Future<void> startSpinify({void Function(Object error)? onError}) async {
    final Spinify client;
    try {
      client = Spinify();
      await client.connect(endpoint.text);
    } on Object catch (e) {
      onError?.call(e);
      return;
    }

    final payload =
        List<int>.generate(payloadSize.value, (index) => index % 256);
    final stopwatch = Stopwatch()..start();
    void pump() {
      _duration = stopwatch.elapsedMilliseconds;
      notifyListeners();
    }

    _total = messageCount.value;
    StreamSubscription<SpinifyPublication>? subscription;
    Completer? completer;
    try {
      _pending = _sent = _received = _failed = 0;
      subscription =
          client.stream.publication(channel: 'benchmark').listen((event) {
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
          pump();
          completer = Completer<void>();
          await client.publish('benchmark', payload);
          _sent++;
          pump();
          await completer.future.timeout(const Duration(seconds: 5));
          pump();
        } on Object catch (e) {
          _failed++;
          onError?.call(e);
          pump();
        }
      }
    } on Object catch (e) {
      onError?.call(e);
      return;
    } finally {
      subscription?.cancel().ignore();
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

class _BenchmarkScaffold extends StatefulWidget {
  const _BenchmarkScaffold({
    required this.themeMode,
    super.key, // ignore: unused_element
  });

  final ValueListenable<ThemeMode> themeMode;

  @override
  State<_BenchmarkScaffold> createState() => _BenchmarkScaffoldState();
}

class _BenchmarkScaffoldState extends State<_BenchmarkScaffold>
    with SingleTickerProviderStateMixin {
  final BenchmarkControllerImpl controller = BenchmarkControllerImpl();
  late final TabController tabBarController;

  @override
  void initState() {
    tabBarController = TabController(length: 2, vsync: this);
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    tabBarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Benchmark'),
          actions: <Widget>[
            ValueListenableBuilder(
              valueListenable: widget.themeMode,
              builder: (context, mode, _) => IconButton(
                icon: switch (mode) {
                  ThemeMode.dark => Icon(Icons.light_mode),
                  ThemeMode.light => Icon(Icons.dark_mode),
                  ThemeMode.system => Icon(Icons.auto_awesome),
                },
                onPressed: () => context
                    .findAncestorStateOfType<_BenchmarkAppState>()
                    ?.toggleTheme(),
              ),
            ),
            SizedBox(width: 8),
          ],
        ),
        bottomNavigationBar: ListenableBuilder(
          listenable: tabBarController,
          builder: (context, _) => BottomNavigationBar(
            currentIndex: tabBarController.index,
            onTap: (index) => tabBarController.animateTo(index),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.speed),
                label: 'Benchmark',
              ),
              /* BottomNavigationBarItem(
                icon: Icon(Icons.device_unknown),
                label: 'Unknown',
              ), */
              BottomNavigationBarItem(
                icon: Icon(Icons.help),
                label: 'Help',
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            controller: tabBarController,
            children: <Widget>[
              Align(
                alignment: Alignment.topCenter,
                child: _BenchmarkTab(
                  controller: controller,
                ),
              ),
              /* Center(
                child: Text('Unknown'),
              ), */
              Center(
                child: Text('Help'),
              ),
            ],
          ),
        ),
      );
}

class _BenchmarkTab extends StatelessWidget {
  const _BenchmarkTab({
    required this.controller,
    super.key, // ignore: unused_element
  });

  final BenchmarkControllerImpl controller;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ValueListenableBuilder<Library>(
              valueListenable: controller.library,
              builder: (context, library, _) => SegmentedButton(
                onSelectionChanged: (value) =>
                    controller.library.value = value.firstOrNull ?? library,
                selected: {library},
                segments: <ButtonSegment<Library>>[
                  ButtonSegment<Library>(
                    value: Library.spinify,
                    label: Text('Spinify'),
                  ),
                  ButtonSegment<Library>(
                    value: Library.centrifuge,
                    label: Text('Centrifuge'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: controller.endpoint,
                decoration: const InputDecoration(
                  labelText: 'Endpoint',
                  hintText: 'ws://localhost:8000/connection/websocket',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                'Payload size',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
            ValueListenableBuilder<int>(
              valueListenable: controller.payloadSize,
              builder: (context, size, _) => Slider(
                value: size.toDouble(),
                min: 0,
                max: 1024 * 1024 * 10,
                divisions: 100,
                label: switch (size) {
                  0 => 'Not set',
                  1 => '1 byte',
                  >= 1024 * 1024 * 1024 => '${size ~/ 1024 ~/ 1024 ~/ 100}GB',
                  >= 1024 * 1024 => '${size ~/ 1024 ~/ 1024}MB',
                  >= 1024 => '${size ~/ 1024}KB',
                  _ => '$size bytes',
                },
                onChanged: (value) =>
                    controller.payloadSize.value = value.toInt(),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                'Message count',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
            ValueListenableBuilder<int>(
              valueListenable: controller.messageCount,
              builder: (context, count, _) => Slider(
                value: count.toDouble(),
                min: 1,
                max: 1000000,
                divisions: 100,
                label: switch (count) {
                  0 => 'Not set',
                  1 => '1 message',
                  >= 1000000 => '${count ~/ 1000000}M messages',
                  >= 1000 => '${count ~/ 1000}k messages',
                  _ => '$count messages',
                },
                onChanged: (value) =>
                    controller.messageCount.value = value.toInt(),
              ),
            ),
            Spacer(),
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) => Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Pending: ${controller.pending}'),
                  Text('Sent: ${controller.sent}'),
                  Text('Received: ${controller.received}'),
                  Text('Failed: ${controller.failed}'),
                  Text('Total: ${controller.total}'),
                  Text('Progress: ${controller.progress}%'),
                  Text('Duration: ${controller.duration}ms'),
                ],
              ),
            ),
            Spacer(),
            Spacer(),
          ],
        ),
      );
}
