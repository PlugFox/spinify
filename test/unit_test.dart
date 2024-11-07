import 'package:test/test.dart';

import 'unit/codec_test.dart' as codec_test;
import 'unit/config_test.dart' as config_test;
import 'unit/jwt_test.dart' as jwt_test;
import 'unit/logs_test.dart' as logs_test;
import 'unit/model_test.dart' as model_test;
import 'unit/server_subscription_test.dart' as server_subscription_test;
import 'unit/spinify_test.dart' as spinify_test;

void main() {
  group('Unit', () {
    model_test.main();
    config_test.main();
    logs_test.main();
    codec_test.main();
    jwt_test.main();
    spinify_test.main();
    server_subscription_test.main();
  });
}
