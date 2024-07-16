import 'package:test/test.dart';

import 'unit/server_subscription_test.dart' as server_subscription_test;
import 'unit/spinify_test.dart' as spinify_test;

void main() {
  group('Unit', () {
    spinify_test.main();
    server_subscription_test.main();
  });
}
