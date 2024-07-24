import 'package:test/test.dart';

import 'smoke/platform_smoke_test.dart' as platform_smoke_test;
import 'smoke/smoke_test.dart' as smoke_test;

void main() {
  group('Smoke', () {
    smoke_test.main();
    platform_smoke_test.main();
  });
}
