import 'dart:async';
import 'dart:io' as io show exit;

import 'package:centrifuge_dart/centrifuge.dart';

void main([List<String>? args]) {
  final client = Centrifuge(
    CentrifugeConfig(
      client: (
        name: 'Centrifuge Console Example',
        version: '0.0.1',
      ),
    ),
  )..connect('ws://localhost:8000/connection/websocket?format=protobuf');

  // TODO(plugfox): Read from stdin and send to channel.

  Timer(
    const Duration(seconds: 1),
    () async {
      await client.close();
      await Future<void>.delayed(const Duration(seconds: 1));
      io.exit(0);
    },
  );
}
