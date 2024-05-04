import 'dart:convert';

import 'package:meta/meta.dart';

/// {@template state}
/// Spinify client connection states
///
/// Client connection has 4 states:
///
/// - disconnected
/// - connecting
/// - connected
/// - closed
///
/// When a new Client is created it has a disconnected state.
/// To connect to a server connect() method must be called.
/// After calling connect Client moves to the connecting state.
/// If a Client can't connect to a server it attempts to create
/// a connection with an exponential backoff algorithm (with full jitter).
/// If a connection to a server is connected then the state becomes connected.
///
/// If a connection is lost (due to a missing network for example,
/// or due to reconnect advice received from a server,
/// or due to some client-side closed that can't be recovered
/// without reconnecting) Client goes to the connecting state again.
/// In this state Client tries to reconnect
/// (again, with an exponential backoff algorithm).
///
/// The Client's state can become disconnected.
/// This happens when Client's disconnect() method was called by a developer.
/// Also, this can happen due to server advice from a server,
/// or due to a terminal problem that happened on the client-side.
/// {@endtemplate}
/// {@category Client}
/// {@category Entity}
@immutable
sealed class SpinifyState extends _$SpinifyStateBase {
  /// {@macro state}
  const SpinifyState(super.timestamp);

  /// Disconnected state
  /// {@macro state}
  factory SpinifyState.disconnected({
    DateTime? timestamp,
    int? closeCode,
    String? closeReason,
  }) = SpinifyState$Disconnected;

  /// Connecting
  /// {@macro state}
  factory SpinifyState.connecting({required String url, DateTime? timestamp}) =
      SpinifyState$Connecting;

  /// Connected
  /// {@macro state}
  factory SpinifyState.connected({
    required String url,
    required bool expires,
    DateTime? timestamp,
    String? client,
    String? version,
    DateTime? ttl,
    Duration? pingInterval,
    bool? sendPong,
    String? session,
    String? node,
    List<int>? data,
  }) = SpinifyState$Connected;

  /// Permanently closed
  /// {@macro state}
  factory SpinifyState.closed({DateTime? timestamp}) = SpinifyState$Closed;

  /// Restore state from JSON
  /// {@macro state}
  factory SpinifyState.fromJson(Map<String, Object?> json) => switch ((
        json['type']?.toString().trim().toLowerCase(),
        json['timestamp'] ?? DateTime.now().microsecondsSinceEpoch,
        json['url'],
      )) {
        ('disconnected', int timestamp, _) => SpinifyState.disconnected(
            timestamp: DateTime.fromMicrosecondsSinceEpoch(timestamp),
            closeCode: switch (json['closeCode']) {
              int closeCode => closeCode,
              _ => null,
            },
            closeReason: switch (json['closeReason']) {
              String closeReason => closeReason,
              _ => null,
            },
          ),
        ('connecting', int timestamp, String url) => SpinifyState.connecting(
            url: url,
            timestamp: DateTime.fromMicrosecondsSinceEpoch(timestamp),
          ),
        ('connected', int timestamp, String url) => SpinifyState.connected(
            url: url,
            timestamp: DateTime.fromMicrosecondsSinceEpoch(timestamp),
            client: json['client']?.toString(),
            version: json['version']?.toString(),
            expires: switch (json['expires']) {
              bool expires => expires,
              _ => false,
            },
            ttl: switch (json['ttl']) {
              int ttl => DateTime.fromMicrosecondsSinceEpoch(ttl),
              _ => null,
            },
            pingInterval: switch (json['pingInterval']) {
              int pingInterval => Duration(seconds: pingInterval),
              _ => null,
            },
            sendPong: switch (json['sendPong']) {
              bool sendPong => sendPong,
              _ => null,
            },
            session: json['session']?.toString(),
            node: json['node']?.toString(),
            data: switch (json['data']) {
              String data when data.isNotEmpty => base64Decode(data),
              _ => null,
            },
          ),
        ('closed', int timestamp, _) => SpinifyState.closed(
            timestamp: DateTime.fromMicrosecondsSinceEpoch(timestamp),
          ),
        _ => throw FormatException('Unknown state: $json'),
      };
}

/// Disconnected
/// Client should handle disconnect advices from server.
/// In websocket case disconnect advice is sent in CLOSE Websocket frame.
/// Disconnect advice contains uint32 code and human-readable string reason.
///
/// {@macro state}
/// {@category Client}
/// {@category Entity}
final class SpinifyState$Disconnected extends SpinifyState {
  /// Disconnected
  ///
  /// {@macro state}
  SpinifyState$Disconnected({
    DateTime? timestamp,
    this.closeCode,
    this.closeReason,
  }) : super(timestamp ?? DateTime.now());

  @override
  String get type => 'disconnected';

  @override
  String? get url => null;

  /// The close code set when the WebSocket connection is closed.
  /// If there is no close code available this property will be null.
  final int? closeCode;

  /// The close reason set when the WebSocket connection is closed.
  /// If there is no close reason available this property will be null.
  final String? closeReason;

  @override
  bool get isDisconnected => true;

  @override
  bool get isConnecting => false;

  @override
  bool get isConnected => false;

  @override
  bool get isClosed => false;

  @override
  R map<R>({
    required SpinifyStateMatch<R, SpinifyState$Disconnected> disconnected,
    required SpinifyStateMatch<R, SpinifyState$Connecting> connecting,
    required SpinifyStateMatch<R, SpinifyState$Connected> connected,
    required SpinifyStateMatch<R, SpinifyState$Closed> closed,
  }) =>
      disconnected(this);

  @override
  Map<String, Object?> toJson() => {
        ...super.toJson(),
        if (closeCode != null) 'closeCode': closeCode,
        if (closeReason != null) 'closeReason': closeReason,
      };

  @override
  int get hashCode => 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SpinifyState$Disconnected &&
          other.timestamp.isAtSameMomentAs(timestamp));

  @override
  String toString() => r'SpinifyState$Disconnected{}';
}

/// Connecting
///
/// {@macro state}
/// {@category Client}
/// {@category Entity}
final class SpinifyState$Connecting extends SpinifyState {
  /// Connecting
  ///
  /// {@macro state}
  SpinifyState$Connecting({required this.url, DateTime? timestamp})
      : super(timestamp ?? DateTime.now());

  @override
  String get type => 'connecting';

  @override
  final String url;

  @override
  bool get isDisconnected => false;

  @override
  bool get isConnecting => true;

  @override
  bool get isConnected => false;

  @override
  bool get isClosed => false;

  @override
  R map<R>({
    required SpinifyStateMatch<R, SpinifyState$Disconnected> disconnected,
    required SpinifyStateMatch<R, SpinifyState$Connecting> connecting,
    required SpinifyStateMatch<R, SpinifyState$Connected> connected,
    required SpinifyStateMatch<R, SpinifyState$Closed> closed,
  }) =>
      connecting(this);

  @override
  int get hashCode => 1;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SpinifyState$Connecting &&
          other.timestamp.isAtSameMomentAs(timestamp));

  @override
  String toString() => r'SpinifyState$Connecting{}';
}

/// Connected
///
/// {@macro state}
/// {@category Client}
/// {@category Entity}
final class SpinifyState$Connected extends SpinifyState {
  /// Connected
  ///
  /// {@macro state}
  SpinifyState$Connected({
    required this.url,
    required this.expires,
    DateTime? timestamp,
    this.client,
    this.version,
    this.ttl,
    this.pingInterval,
    this.sendPong,
    this.session,
    this.node,
    this.data,
  }) : super(timestamp ?? DateTime.now());

  @override
  String get type => 'connected';

  @override
  final String url;

  /// Unique client connection ID server issued to this connection
  final String? client;

  /// Server version
  final String? version;

  /// Whether a server will expire connection at some point
  final bool expires;

  /// Time when connection will be expired
  final DateTime? ttl;

  /// Client must periodically (once in 25 secs, configurable) send
  /// ping messages to server. If pong has not beed received in 5 secs
  /// (configurable) then client must disconnect from server
  /// and try to reconnect with backoff strategy.
  final Duration? pingInterval;

  /// Whether to send asynchronous message when pong received.
  final bool? sendPong;

  /// Session ID.
  final String? session;

  /// Server node ID.
  final String? node;

  /// Additional data returned from server on connect.
  final List<int>? data;

  @override
  bool get isDisconnected => false;

  @override
  bool get isConnecting => false;

  @override
  bool get isConnected => true;

  @override
  bool get isClosed => false;

  @override
  R map<R>({
    required SpinifyStateMatch<R, SpinifyState$Disconnected> disconnected,
    required SpinifyStateMatch<R, SpinifyState$Connecting> connecting,
    required SpinifyStateMatch<R, SpinifyState$Connected> connected,
    required SpinifyStateMatch<R, SpinifyState$Closed> closed,
  }) =>
      connected(this);

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        ...super.toJson(),
        if (client != null) 'client': client,
        if (version != null) 'version': version,
        'expires': expires,
        if (ttl != null) 'ttl': ttl?.microsecondsSinceEpoch,
        if (pingInterval != null) 'pingInterval': pingInterval?.inSeconds,
        if (sendPong != null) 'sendPong': sendPong,
        if (session != null) 'session': session,
        if (node != null) 'node': node,
        if (data != null) 'data': base64Encode(data!),
      };

  @override
  int get hashCode => 2;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SpinifyState$Connected &&
          other.timestamp.isAtSameMomentAs(timestamp));

  @override
  String toString() => r'SpinifyState$Connected{}';
}

/// Permanently closed
///
/// {@macro state}
/// {@category Client}
/// {@category Entity}
final class SpinifyState$Closed extends SpinifyState {
  /// Permanently closed
  ///
  /// {@macro state}
  SpinifyState$Closed({DateTime? timestamp})
      : super(timestamp ?? DateTime.now());

  @override
  String get type => 'closed';

  @override
  String? get url => null;

  @override
  bool get isDisconnected => false;

  @override
  bool get isConnecting => false;

  @override
  bool get isConnected => true;

  @override
  bool get isClosed => false;

  @override
  R map<R>({
    required SpinifyStateMatch<R, SpinifyState$Disconnected> disconnected,
    required SpinifyStateMatch<R, SpinifyState$Connecting> connecting,
    required SpinifyStateMatch<R, SpinifyState$Connected> connected,
    required SpinifyStateMatch<R, SpinifyState$Closed> closed,
  }) =>
      closed(this);

  @override
  int get hashCode => 3;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SpinifyState$Closed &&
          other.timestamp.isAtSameMomentAs(timestamp));

  @override
  String toString() => r'SpinifyState$Closed{}';
}

/// Pattern matching for [SpinifyState].
/// {@category Entity}
typedef SpinifyStateMatch<R, S extends SpinifyState> = R Function(S state);

@immutable
abstract base class _$SpinifyStateBase {
  const _$SpinifyStateBase(this.timestamp);

  /// Represents the current state type.
  abstract final String type;

  /// URL of endpoint.
  abstract final String? url;

  /// Disconnected state
  abstract final bool isDisconnected;

  /// Connecting state
  abstract final bool isConnecting;

  /// Connected state
  abstract final bool isConnected;

  /// Closed state
  abstract final bool isClosed;

  /// Timestamp of state change.
  final DateTime timestamp;

  /// Pattern matching for [SpinifyState].
  R map<R>({
    required SpinifyStateMatch<R, SpinifyState$Disconnected> disconnected,
    required SpinifyStateMatch<R, SpinifyState$Connecting> connecting,
    required SpinifyStateMatch<R, SpinifyState$Connected> connected,
    required SpinifyStateMatch<R, SpinifyState$Closed> closed,
  });

  /// Pattern matching for [SpinifyState].
  R maybeMap<R>({
    required R Function() orElse,
    SpinifyStateMatch<R, SpinifyState$Disconnected>? disconnected,
    SpinifyStateMatch<R, SpinifyState$Connecting>? connecting,
    SpinifyStateMatch<R, SpinifyState$Connected>? connected,
    SpinifyStateMatch<R, SpinifyState$Closed>? closed,
  }) =>
      map<R>(
        disconnected: disconnected ?? (_) => orElse(),
        connecting: connecting ?? (_) => orElse(),
        connected: connected ?? (_) => orElse(),
        closed: closed ?? (_) => orElse(),
      );

  /// Pattern matching for [SpinifyState].
  R? mapOrNull<R>({
    SpinifyStateMatch<R, SpinifyState$Disconnected>? disconnected,
    SpinifyStateMatch<R, SpinifyState$Connecting>? connecting,
    SpinifyStateMatch<R, SpinifyState$Connected>? connected,
    SpinifyStateMatch<R, SpinifyState$Closed>? closed,
  }) =>
      map<R?>(
        disconnected: disconnected ?? (_) => null,
        connecting: connecting ?? (_) => null,
        connected: connected ?? (_) => null,
        closed: closed ?? (_) => null,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'type': type,
        'timestamp': timestamp.toUtc().toIso8601String(),
        if (url != null) 'url': url,
      };
}
