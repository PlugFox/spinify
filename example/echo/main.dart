// ignore_for_file: avoid_print

import 'package:spinify/spinify.dart';

const url = 'ws://localhost:8000/connection/websocket';

void main() {
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
