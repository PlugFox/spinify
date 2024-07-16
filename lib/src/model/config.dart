import 'dart:async';

import 'package:meta/meta.dart';

import 'pubspec.yaml.g.dart';
import 'transport_interface.dart';

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

/// Log level for logger
extension type const SpinifyLogLevel._(int level) implements int {
  /// Log level: debug
  @literal
  const SpinifyLogLevel.debug() : level = 0;

  /// Log level: transport
  @literal
  const SpinifyLogLevel.transport() : level = 1;

  /// Log level: config
  @literal
  const SpinifyLogLevel.config() : level = 2;

  /// Log level: info
  @literal
  const SpinifyLogLevel.info() : level = 3;

  /// Log level: warning
  @literal
  const SpinifyLogLevel.warning() : level = 4;

  /// Log level: error
  @literal
  const SpinifyLogLevel.error() : level = 5;

  /// Log level: critical
  @literal
  const SpinifyLogLevel.critical() : level = 6;

  /// Pattern matching on log level
  T map<T>({
    required T Function() debug,
    required T Function() transport,
    required T Function() config,
    required T Function() info,
    required T Function() warning,
    required T Function() error,
    required T Function() critical,
  }) =>
      switch (level) {
        0 => debug(),
        1 => transport(),
        2 => config(),
        3 => info(),
        4 => warning(),
        5 => error(),
        6 => critical(),
        _ => throw AssertionError('Unknown log level: $level'),
      };

  /// Pattern matching on log level
  T maybeMap<T>({
    required T Function() orElse,
    T Function()? debug,
    T Function()? transport,
    T Function()? config,
    T Function()? info,
    T Function()? warning,
    T Function()? error,
    T Function()? critical,
  }) =>
      map<T>(
        debug: debug ?? orElse,
        transport: transport ?? orElse,
        config: config ?? orElse,
        info: info ?? orElse,
        warning: warning ?? orElse,
        error: error ?? orElse,
        critical: critical ?? orElse,
      );

  /// Pattern matching on log level
  T? mapOrNull<T>({
    T Function()? debug,
    T Function()? transport,
    T Function()? config,
    T Function()? info,
    T Function()? warning,
    T Function()? error,
    T Function()? critical,
  }) =>
      maybeMap<T?>(
        orElse: () => null,
        debug: debug,
        transport: transport,
        config: config,
        info: info,
        warning: warning,
        error: error,
        critical: critical,
      );

  /// If log level is warning or higher
  bool get isError => level > 3;
}

/// Logger function to use for logging.
/// If not specified, the logger will be disabled.
/// The logger function is called with the following arguments:
/// - [level] - the log verbose level 0..6
///  * 0 - debug
///  * 1 - transport
///  * 2 - config
///  * 3 - info
///  * 4 - warning
///  * 5 - error
///  * 6 - critical
/// - [event] - the log event, unique type of log event
/// - [message] - the log message
/// - [context] - the log context data
typedef SpinifyLogger = void Function(
  SpinifyLogLevel level,
  String event,
  String message,
  Map<String, Object?> context,
);

/// {@template spinify_log_buffer}
/// Circular buffer for storing log entries.
/// {@endtemplate}
final class SpinifyLogBuffer {
  /// {@macro spinify_log_buffer}
  SpinifyLogBuffer({
    this.size = 1000,
  }) : _logs = List.filled(size.clamp(0, 100000), null, growable: false);

  /// The maximum number of log entries to keep in the buffer.
  final int size;

  /// The number of log entries currently in the buffer.
  int get length => _length;

  /// Whether the buffer is empty.
  bool get isEmpty => _logs.first == null;

  /// Whether the buffer is full.
  bool get isFull => _logs.last != null;

  int _index = 0;
  int _length = 0;

  final List<
      ({
        SpinifyLogLevel level,
        String event,
        String message,
        Map<String, Object?> context
      })?> _logs;

  /// Get all log entries from the buffer.
  List<
      ({
        SpinifyLogLevel level,
        String event,
        String message,
        Map<String, Object?> context
      })> get logs {
    if (_logs.last == null) {
      return _logs.sublist(0, _index).cast();
    } else if (_index == 0) {
      return _logs.cast();
    } else {
      return [
        ..._logs.sublist(_index),
        ..._logs.sublist(0, _index),
      ].cast();
    }
  }

  /// Add a log entry to the buffer.
  void add({
    required SpinifyLogLevel level,
    required String event,
    required String message,
    required Map<String, Object?> context,
  }) {
    _logs[_index] = (
      level: level,
      event: event,
      message: message,
      context: context,
    );
    if (_length < size) {
      _length++;
      _index++;
    } else {
      _index = (_index + 1) % size;
    }
  }

  /// Clear all log entries from the buffer.
  void clear() {
    for (var i = 0; i < _length; i++) {
      _logs[i] = null;
    }
    _length = 0;
    _index = 0;
  }
}

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
    Map<String, String>? headers,
    this.logger,
    this.transportBuilder,
  })  : headers = Map<String, String>.unmodifiable(
            headers ?? const <String, String>{}),
        client = client ??
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
  final Map<String, String> headers;

  /// Maximum time to wait for the connection to be established.
  /// If not specified, the timeout will be 15 seconds.
  final Duration timeout;

  /// Logger function to use for logging.
  /// If not specified, the logger will be disabled.
  /// The logger function is called with the following arguments:
  /// - [level] - the log verbose level 0..6
  ///  * 0 - debug
  ///  * 1 - transport
  ///  * 2 - config
  ///  * 3 - info
  ///  * 4 - warning
  ///  * 5 - error
  ///  * 6 - critical
  /// - [event] - the log event, unique type of log event
  /// - [message] - the log message
  /// - [context] - the log context data
  final SpinifyLogger? logger;

  /// Callback to build Spinify transport.
  final SpinifyTransportBuilder? transportBuilder;

  @override
  String toString() => 'SpinifyConfig{}';
}
