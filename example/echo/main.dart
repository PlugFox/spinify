// ignore_for_file: avoid_print, implicit_call_tearoffs

import 'dart:async';
import 'dart:io' as io;

import 'package:spinify/spinify.dart';

void main(List<String> args) async {
  var url = args.firstWhere((a) => a.startsWith('--url='), orElse: () => '');
  if (url.isNotEmpty) url = url.substring(6).trim();
  if (url.isEmpty) url = io.Platform.environment['URL'] ?? '';
  if (url.isEmpty) url = const String.fromEnvironment('URL', defaultValue: '');
  if (url.isEmpty) url = 'ws://localhost:8000/connection/websocket';

  final httpClient = io.HttpClient(
    context: io.SecurityContext(
      withTrustedRoots: true,
    ), //..setTrustedCertificatesBytes([/* bytes array */])
  );

  final client = Spinify(
    config: SpinifyConfig(
      client: (name: 'app', version: '1.0.0'),
      timeout: const Duration(seconds: 15),
      serverPingDelay: const Duration(seconds: 8),
      connectionRetryInterval: (
        min: const Duration(milliseconds: 250),
        max: const Duration(seconds: 15),
      ),
      /* getToken: () async => '<token>', */
      /* getPayload: () async => utf8.encode('Hello, World!'), */
      codec: SpinifyProtobufCodec(),
      transportBuilder: SpinifyTransportAdapter.vm(
        compression: io.CompressionOptions.compressionDefault,
        customClient: httpClient,
        userAgent: 'Dart',
      ),
      logger: (level, event, message, context) => print('[$event] $message'),
    ),
  );

  Timer(const Duration(minutes: 1), () async {
    await client.close();
    io.exit(0);
  });

  var prev = client.state;
  client.states.listen((next) {
    print('$prev -> $next');
    prev = next;
  });

  await client.connect(url);
}
