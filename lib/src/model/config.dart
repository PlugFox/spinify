import 'package:centrifuge_dart/src/model/pubspec.yaml.g.dart';
import 'package:meta/meta.dart';

/// Token used for authentication
//typedef CentrifugeToken = String;

/// Callback to get/refresh tokens
//typedef CentrifugeTokenCallback = Future<CentrifugeToken> Function();

/// {@template centrifuge_config}
/// Centrifuge client common options.
///
/// There are several common options available when creating Client instance.
/// {@endtemplate}
@immutable
final class CentrifugeConfig {
  /// {@macro centrifuge_config}
  CentrifugeConfig({
    ({Duration min, Duration max})? connectionRetryInterval,
    ({String name, String version})? client,
    this.headers,
  })  : connectionRetryInterval = connectionRetryInterval ??
            (
              min: const Duration(milliseconds: 500),
              max: const Duration(seconds: 30),
            ),
        client = client ??
            (
              name: Pubspec.name,
              version: Pubspec.version.canonical,
            );

  /// Create a default config
  ///
  /// {@macro centrifuge_config}
  factory CentrifugeConfig.defaultConfig() = CentrifugeConfig;

  // TODO(plugfox): Add support for the following options.
  /// The data send for the first request
  //final List<int>? data;

  /// The initial token used for authentication
  //CentrifugeToken token;

  /// Callback to get/refresh tokens
  //final CentrifugeTokenCallback? getToken;

  /// The [connectionRetryInterval] argument is specifying the
  /// [backoff full jitter strategy](https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/) for reconnecting.
  /// Tweaks for reconnect backoff algorithm (min delay, max delay)
  /// If not specified, the reconnecting will be disabled.
  final ({Duration min, Duration max}) connectionRetryInterval;

  /// The user's client name and version.
  final ({String name, String version}) client;

  /// Headers that are set when connecting the web socket on dart:io platforms.
  ///
  /// Note that headers are ignored on the web platform.
  final Map<String, Object?>? headers;

  @override
  String toString() => 'CentrifugeConfig{}';
}
