library;

import 'dart:async';

void runServer() {
  Timer.periodic(const Duration(seconds: 1), (timer) {
    print(DateTime.now());
  });
}
