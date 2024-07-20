import 'package:test/test.dart';

import 'smoke/smoke_test.dart' as smoke_test;
import 'smoke/transport_ws_pb_js_test.dart' as transport_ws_pb_js_test;

void main() {
  group('Smoke', () {
    smoke_test.main();
    transport_ws_pb_js_test.main();
  });
}
