import 'package:test/test.dart';

import 'unit/codec_test.dart' as codec_test;
import 'unit/config_test.dart' as config_test;
import 'unit/jwt_test.dart' as jwt_test;
import 'unit/logs_test.dart' as logs_test;
import 'unit/model_test.dart' as model_test;
import 'unit/spinify_test.dart' as spinify_test;
import 'unit/subscription_test.dart' as subscription_test;
import 'unit/util_test.dart' as util_test;

void main() {
  group('Unit', () {
    util_test.main();
    model_test.main();
    config_test.main();
    logs_test.main();
    codec_test.main();
    jwt_test.main();
    spinify_test.main();
    subscription_test.main();
  });
}
