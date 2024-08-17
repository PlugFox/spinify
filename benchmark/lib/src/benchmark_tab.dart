import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spinifybenchmark/src/benchmark_controller.dart';
import 'package:spinifybenchmark/src/constant.dart';

class BenchmarkTab extends StatelessWidget {
  const BenchmarkTab({
    required this.controller,
    super.key, // ignore: unused_element
  });

  final IBenchmarkController controller;

  static String _formatBytes(int bytes) => switch (bytes) {
        0 => '0 bytes',
        1 => '1 byte',
        >= 1024 * 1024 * 1024 => '${bytes ~/ 1024 ~/ 1024 ~/ 100}GB',
        >= 1024 * 1024 => '${bytes ~/ 1024 ~/ 1024}MB',
        >= 1024 => '${bytes ~/ 1024}KB',
        _ => '$bytes bytes',
      };

  static String _formatMs(int ms) => switch (ms) {
        0 => '0ms',
        >= 1000 * 60 * 60 => '${ms ~/ 1000 ~/ 60 ~/ 60}h',
        >= 1000 * 60 => '${ms ~/ 1000 ~/ 60}m',
        >= 1000 => '${ms ~/ 1000}s',
        _ => '${ms}ms',
      };

  @override
  Widget build(BuildContext context) => ListView(
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ValueListenableBuilder<Library>(
                      valueListenable: controller.library,
                      builder: (context, library, _) => SegmentedButton(
                        onSelectionChanged: (value) => controller
                            .library.value = value.firstOrNull ?? library,
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
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Wrap(
                      direction: Axis.horizontal,
                      alignment: WrapAlignment.start,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      runAlignment: WrapAlignment.start,
                      verticalDirection: VerticalDirection.down,
                      runSpacing: 4,
                      children: <Widget>[
                        IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () async {
                            final messenger =
                                ScaffoldMessenger.maybeOf(context);
                            await Clipboard.setData(
                                const ClipboardData(text: tokenHmacSecretKey));
                            messenger
                              ?..clearSnackBars()
                              ..showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Copied HMAC secret key to clipboard'),
                                  duration: Duration(seconds: 5),
                                ),
                              );
                          },
                        ),
                        Text(
                          'Token HMAC Secret Key:',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        SelectableText(
                          tokenHmacSecretKey,
                          maxLines: 1,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: TextField(
                      controller: controller.endpoint,
                      decoration: const InputDecoration(
                        labelText: 'Endpoint',
                        hintText: defaultEndpoint,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Payload size',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: controller.payloadSize,
                    builder: (context, size, _) => Slider(
                      value: size.toDouble(),
                      min: 1,
                      max: 65510,
                      divisions: 100,
                      label: _formatBytes(size),
                      onChanged: (value) =>
                          controller.payloadSize.value = value.toInt(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
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
                      max: 10000,
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
          const Divider(height: 48),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: SizedBox(
              height: 24,
              child: CustomPaint(
                painter: ProgressPainter(controller),
                child: const SizedBox(height: 8),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => Wrap(
              direction: Axis.horizontal,
              alignment: WrapAlignment.spaceEvenly,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runAlignment: WrapAlignment.spaceEvenly,
              verticalDirection: VerticalDirection.down,
              runSpacing: 16,
              children: <Widget>[
                SizedBox.square(
                  dimension: 128,
                  child: Center(
                    child: ValueListenableBuilder<bool>(
                      valueListenable: controller.isRunning,
                      builder: (context, running, child) => IconButton(
                        iconSize: 92,
                        tooltip: 'Start benchmark',
                        icon: Icon(running ? Icons.timer : Icons.play_arrow,
                            color: running ? Colors.grey : Colors.green),
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
                                        duration: const Duration(seconds: 5),
                                      ),
                                    ),
                                );
                              },
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: 512,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () async {
                            final messenger =
                                ScaffoldMessenger.maybeOf(context);
                            final buffer = StringBuffer()
                              ..writeln(
                                  'Library: ${controller.library.value.name}')
                              ..writeln('Sent: ${controller.sent} '
                                  '(${_formatBytes(controller.sentBytes)})')
                              ..writeln('Received: ${controller.received} '
                                  '(${_formatBytes(controller.receivedBytes)})')
                              ..writeln('Failed: ${controller.failed}')
                              ..writeln('Total: ${controller.total}')
                              ..writeln('Progress: ${controller.progress}%')
                              ..writeln(
                                  'Duration: ${_formatMs(controller.duration)}')
                              ..writeln(
                                  'Speed: ${controller.messagePerSecond} msg/s '
                                  '(${_formatBytes(controller.bytesPerSecond)}/s)');

                            await Clipboard.setData(
                                ClipboardData(text: buffer.toString()));
                            messenger
                              ?..clearSnackBars()
                              ..showSnackBar(
                                const SnackBar(
                                  content: Text('Copied to clipboard.'),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                          },
                        ),
                        const SizedBox(width: 8),
                        SelectionArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Pending: ${controller.pending}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Sent: ${controller.sent} '
                                '(${_formatBytes(controller.sentBytes)})',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Received: ${controller.received} '
                                '(${_formatBytes(controller.receivedBytes)})',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Failed: ${controller.failed}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Total: ${controller.total}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Progress: ${controller.progress}%',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Duration: ${_formatMs(controller.duration)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Speed: ${controller.messagePerSecond} msg/s '
                                '(${_formatBytes(controller.bytesPerSecond)}/s)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Status: ${controller.status}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

class ProgressPainter extends CustomPainter {
  const ProgressPainter(this.controller) : super(repaint: controller);

  final IBenchmarkController controller;

  static final backgroundPaint = Paint()
    ..color = Colors.grey
    ..strokeWidth = 8
    ..strokeCap = StrokeCap.round;

  static final progressPaint = Paint()
    ..color = Colors.green
    ..strokeWidth = 8
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromLTRBR(
        0,
        0,
        size.width,
        size.height,
        const Radius.circular(8),
      ),
      backgroundPaint,
    );
    if (controller.isRunning.value)
      canvas.drawRRect(
        RRect.fromLTRBR(
          0,
          0,
          controller.progress / 100 * size.width,
          size.height,
          const Radius.circular(8),
        ),
        progressPaint,
      );
  }

  @override
  bool shouldRepaint(ProgressPainter oldDelegate) => false;

  @override
  bool shouldRebuildSemantics(ProgressPainter oldDelegate) => false;
}
