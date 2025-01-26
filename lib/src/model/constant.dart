import 'platform/vm.dart'
    // ignore: uri_does_not_exist
    if (dart.library.js_interop) 'platform/js.dart';

/// Whether the current platform is web.
const bool kIsWeb = $kIsWeb; // identical(0, 0.0);

/// Maximum integer value.
const int kMaxInt = int.fromEnvironment(
  'SPINIFY_MAX_INT',
  defaultValue: 0x20000000000000, // 0x7FFFFFFFFFFFFFFF
);
