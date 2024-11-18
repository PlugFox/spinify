// ignore_for_file: avoid_print

import 'dart:io' as io;

import 'package:spinify/spinify.dart';

void main(List<String> args) {
  var url = args.firstWhere((a) => a.startsWith('--url='), orElse: () => '');
  if (url.isNotEmpty) url = url.substring(6).trim();
  if (url.isEmpty) url = io.Platform.environment['URL'] ?? '';
  if (url.isEmpty) url = const String.fromEnvironment('URL', defaultValue: '');
  if (url.isEmpty) url = 'ws://localhost:8000/connection/websocket';

  final client = Spinify(
    config: SpinifyConfig(
      logger: (level, event, message, context) => print('[$event] $message'),
    ),
  );

  var prev = client.state;
  client.states.listen((next) {
    print('$prev -> $next');
    prev = next;
  });

  client.connect(url).ignore();
}
