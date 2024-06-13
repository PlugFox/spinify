import 'dart:async';

import 'package:meta/meta.dart';

import '../model/pubspec.yaml.g.dart';

/// Token used for authentication
///
/// {@category Client}
/// {@category Entity}
typedef SpinifyToken = String;

/// Callback to get/refresh tokens
/// This callback is used for initial connection
/// and for refreshing expired tokens.
///
/// If method returns null then connection will be established without token.
///
/// {@category Client}
/// {@category Entity}
typedef SpinifyTokenCallback = Future<SpinifyToken?> Function();

/// Callback to get initial connection payload data.
///
/// If method returns null then no payload will be sent at connect time.
///
/// {@category Client}
/// {@category Entity}
typedef SpinifyConnectionPayloadCallback = Future<List<int>?> Function();

/// {@template spinify_config}
/// Spinify client common options.
///
/// There are several common options available when creating Client instance.
///
/// - [connectionRetryInterval] - tweaks for reconnect backoff
/// - [client] - the user's client name and version
/// - [headers] - headers that are set when connecting the web socket
/// - [timeout] - maximum time to wait for the connection to be established
/// {@endtemplate}
/// {@category Client}
/// {@category Entity}
@immutable
final class SpinifyConfig {
  /// {@macro spinify_config}
  SpinifyConfig({
    this.getToken,
    this.getPayload,
    this.connectionRetryInterval = (
      min: const Duration(milliseconds: 500),
      max: const Duration(seconds: 20),
    ),
    ({String name, String version})? client,
    this.timeout = const Duration(seconds: 15),
    this.serverPingDelay = const Duration(seconds: 8),
    this.headers,
  }) : client = client ??
            (
              name: Pubspec.name,
              version: Pubspec.version.canonical,
            );

  /// Create a default config
  ///
  /// {@macro spinify_config}
  factory SpinifyConfig.byDefault() = SpinifyConfig;

  /// Callback to get/refresh tokens
  /// This callback is used for initial connection
  /// and for refreshing expired tokens.
  ///
  /// If method returns null then connection will be established without token.
  final SpinifyTokenCallback? getToken;

  /// Callback to get connection payload data.
  /// The resulted data send with every connect request.
  ///
  /// If method returns null then no payload will be sent at connect time.
  final SpinifyConnectionPayloadCallback? getPayload;

  /// The additional delay between expected server heartbeat pings.
  ///
  /// Centrifugo server periodically sends pings to clients and expects pong
  /// from clients that works over bidirectional transports.
  /// Sending ping and receiving pong allows to find broken connections faster.
  /// Centrifugo sends pings on the Centrifugo client protocol level,
  /// thus it's possible for clients to handle ping messages
  /// on the client side to make sure connection is not broken.
  ///
  /// Centrifugo expects pong message
  /// from bidirectional client SDK after sending ping to it.
  /// By default, it waits no more than 8 seconds before closing a connection.
  final Duration serverPingDelay;

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
  String toString() => 'SpinifyConfig{}';
}
