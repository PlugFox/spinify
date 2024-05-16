/// Whether the current platform is web.
const bool kIsWeb = identical(0, 0.0);

/// Maximum integer value.
const int kMaxInt = int.fromEnvironment('SPINIFY_MAX_INT',
    defaultValue: kIsWeb ? 0x20000000000000 : 0x7FFFFFFFFFFFFFFF);
