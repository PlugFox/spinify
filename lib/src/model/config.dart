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
    this.data,
    ({Duration min, Duration max})? reconnectDelay,
    ({String name, String version})? client,
  })  : reconnectDelay = reconnectDelay ??
            (
              min: const Duration(milliseconds: 500),
              max: const Duration(seconds: 20),
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

  /// The initial token used for authentication
  //CentrifugeToken token;

  /// Callback to get/refresh tokens
  //final CentrifugeTokenCallback? getToken;

  /// The connection timeout
  //final Duration timeout;

  /// Native WebSocket config
  /// sealed class WebSocketConfig => WebSocketConfig$VM | WebSocketConfig$JS

  /// The data send for the first request
  final List<int>? data;

  /// Reconnect backoff algorithm minimum/maximum delay.
  final ({Duration min, Duration max}) reconnectDelay;

  /// The user's client name and version.
  final ({String name, String version}) client;

  @override
  String toString() => 'CentrifugeConfig{}';
}
