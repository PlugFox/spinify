import 'dart:async';

import 'package:centrifuge_dart/src/model/pubspec.yaml.g.dart';
import 'package:meta/meta.dart';

/// Token used for authentication
typedef CentrifugeToken = String;

/// Callback to get/refresh tokens
/// This callback is used for initial connection
/// and for refreshing expired tokens.
///
/// If method returns null then connection will be established without token.
typedef CentrifugeTokenCallback = FutureOr<CentrifugeToken?> Function();

/// Callback to get initial connection payload data.
/// For example to send JWT or other auth data.
///
/// If method returns null then no payload will be sent at connect time.
typedef CentrifugeConnectionPayloadCallback = FutureOr<List<int>?> Function();

/// {@template centrifuge_config}
/// Centrifuge client common options.
///
/// There are several common options available when creating Client instance.
///
/// - [connectionRetryInterval] - tweaks for reconnect backoff
/// - [client] - the user's client name and version
/// - [headers] - headers that are set when connecting the web socket
/// - [timeout] - maximum time to wait for the connection to be established
/// {@endtemplate}
@immutable
final class CentrifugeConfig {
  /// {@macro centrifuge_config}
  CentrifugeConfig({
    this.getToken,
    this.getPayload,
    ({Duration min, Duration max})? connectionRetryInterval,
    ({String name, String version})? client,
    this.timeout = const Duration(seconds: 15),
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

  /// Callback to get/refresh tokens
  /// This callback is used for initial connection
  /// and for refreshing expired tokens.
  ///
  /// If method returns null then connection will be established without token.
  final CentrifugeTokenCallback? getToken;

  /// The data send for the first request
  /// Callback to get initial connection payload data.
  /// For example to send JWT or other auth data.
  ///
  /// If method returns null then no payload will be sent at connect time.
  final CentrifugeConnectionPayloadCallback? getPayload;

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

  /// Maximum time to wait for the connection to be established.
  /// If not specified, the timeout will be 15 seconds.
  final Duration timeout;

  @override
  String toString() => 'CentrifugeConfig{}';
}
