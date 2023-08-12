/// Config for app.
abstract final class Config {
  /// Environment flavor.
  /// e.g. development, staging, production
  static final EnvironmentFlavor environment = EnvironmentFlavor.from(
      const String.fromEnvironment('ENVIRONMENT', defaultValue: 'development'));

  // --- Centrifuge --- //

  /// Centrifuge url.
  /// e.g. https://domain.tld
  static const String centrifugeBaseUrl = String.fromEnvironment(
      'CENTRIFUGE_BASE_URL',
      defaultValue: 'http://127.0.0.1:8000');

  /// Centrifuge timeout in milliseconds.
  /// e.g. 15000 ms
  static const Duration centrifugeTimeout = Duration(
      milliseconds:
          int.fromEnvironment('CENTRIFUGE_TIMEOUT', defaultValue: 15000));

  /// Secret for HMAC token.
  static const String centrifugeToken =
      String.fromEnvironment('CENTRIFUGE_TOKEN_HMAC_SECRET');

  /// Channel by default.
  static const String centrifugeChannel =
      String.fromEnvironment('CENTRIFUGE_CHANNEL');

  /// Username by default.
  static const String centrifugeUsername =
      String.fromEnvironment('CENTRIFUGE_USERNAME');
  // --- Layout --- //

  /// Maximum screen layout width for screen with list view.
  static const int maxScreenLayoutWidth =
      int.fromEnvironment('MAX_LAYOUT_WIDTH', defaultValue: 768);
}

/// Environment flavor.
/// e.g. development, staging, production
enum EnvironmentFlavor {
  /// Development
  development('development'),

  /// Staging
  staging('staging'),

  /// Production
  production('production');

  /// {@nodoc}
  const EnvironmentFlavor(this.value);

  /// {@nodoc}
  factory EnvironmentFlavor.from(String? value) =>
      switch (value?.trim().toLowerCase()) {
        'development' || 'debug' || 'develop' || 'dev' => development,
        'staging' || 'profile' || 'stage' || 'stg' => staging,
        'production' || 'release' || 'prod' || 'prd' => production,
        _ => const bool.fromEnvironment('dart.vm.product')
            ? production
            : development,
      };

  /// development, staging, production
  final String value;

  /// Whether the environment is development.
  bool get isDevelopment => this == development;

  /// Whether the environment is staging.
  bool get isStaging => this == staging;

  /// Whether the environment is production.
  bool get isProduction => this == production;
}
