import 'package:flutter/material.dart';
import 'package:spinifybenchmark/src/benchmark_controller.dart';

class BenchmarkTab extends StatelessWidget {
  const BenchmarkTab({
    required this.controller,
    super.key, // ignore: unused_element
  });

  final IBenchmarkController controller;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ValueListenableBuilder<bool>(
            valueListenable: controller.isRunning,
            builder: (context, running, child) => AbsorbPointer(
              absorbing: running,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: running ? 0.5 : 1,
                child: child,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ValueListenableBuilder<Library>(
                    valueListenable: controller.library,
                    builder: (context, library, _) => SegmentedButton(
                      onSelectionChanged: (value) => controller.library.value =
                          value.firstOrNull ?? library,
                      selected: {library},
                      segments: const <ButtonSegment<Library>>[
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
                        >= 1024 * 1024 * 1024 =>
                          '${size ~/ 1024 ~/ 1024 ~/ 100}GB',
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
                ],
              ),
            ),
          ),
          const Spacer(),
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                ValueListenableBuilder<bool>(
                  valueListenable: controller.isRunning,
                  builder: (context, running, child) => IconButton(
                    iconSize: 64,
                    icon: Icon(running ? Icons.timer : Icons.play_arrow,
                        color: running ? Colors.grey : Colors.red),
                    onPressed: running
                        ? null
                        : () {
                            final messenger =
                                ScaffoldMessenger.maybeOf(context);
                            controller.start(
                              onError: (error) => messenger
                                ?..clearSnackBars()
                                ..showSnackBar(
                                  SnackBar(
                                    content: Text('$error'),
                                    backgroundColor: Colors.red,
                                  ),
                                ),
                            );
                          },
                  ),
                ),
                Column(
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
                    Text('Status: ${controller.status}'),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
      );
}
