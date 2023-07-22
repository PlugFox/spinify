import 'package:meta/meta.dart';

/// {@template state}
/// Centrifuge client connection states
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
sealed class CentrifugeState extends _$CentrifugeStateBase {
  /// {@macro state}
  const CentrifugeState(super.timestamp);

  /// Disconnected state
  /// {@macro state}
  factory CentrifugeState.disconnected({
    DateTime? timestamp,
    int? closeCode,
    String? closeReason,
  }) = CentrifugeState$Disconnected;

  /// Connecting
  /// {@macro state}
  factory CentrifugeState.connecting(
      {required String url, DateTime? timestamp}) = CentrifugeState$Connecting;

  /// Connected
  /// {@macro state}
  factory CentrifugeState.connected({
    required String url,
    DateTime? timestamp,
    String? client,
    String? version,
    bool? expires,
    DateTime? ttl,
    Duration? pingInterval,
    bool? sendPong,
    String? session,
    String? node,
  }) = CentrifugeState$Connected;

  /// Permanently closed
  /// {@macro state}
  factory CentrifugeState.closed({DateTime? timestamp}) =
      CentrifugeState$Closed;

  /// Restore state from JSON
  /// {@macro state}
  factory CentrifugeState.fromJson(Map<String, Object?> json) => switch ((
        json['type']?.toString().trim().toLowerCase(),
        json['timestamp'] ?? DateTime.now().microsecondsSinceEpoch,
        json['url'],
      )) {
        ('disconnected', int timestamp, _) => CentrifugeState.disconnected(
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
        ('connecting', int timestamp, String url) => CentrifugeState.connecting(
            url: url,
            timestamp: DateTime.fromMicrosecondsSinceEpoch(timestamp),
          ),
        ('connected', int timestamp, String url) => CentrifugeState.connected(
            url: url,
            timestamp: DateTime.fromMicrosecondsSinceEpoch(timestamp),
            client: json['client']?.toString(),
            version: json['version']?.toString(),
            expires: switch (json['expires']) {
              bool expires => expires,
              _ => null,
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
          ),
        ('closed', int timestamp, _) => CentrifugeState.closed(
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
final class CentrifugeState$Disconnected extends CentrifugeState
    with _$CentrifugeState {
  /// Disconnected
  ///
  /// {@macro state}
  CentrifugeState$Disconnected({
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
    required CentrifugeStateMatch<R, CentrifugeState$Disconnected> disconnected,
    required CentrifugeStateMatch<R, CentrifugeState$Connecting> connecting,
    required CentrifugeStateMatch<R, CentrifugeState$Connected> connected,
    required CentrifugeStateMatch<R, CentrifugeState$Closed> closed,
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
      (other is CentrifugeState$Disconnected &&
          other.timestamp.isAtSameMomentAs(timestamp));

  @override
  String toString() => 'CentrifugeState.disconnected{$timestamp}';
}

/// Connecting
///
/// {@macro state}
final class CentrifugeState$Connecting extends CentrifugeState
    with _$CentrifugeState {
  /// Connecting
  ///
  /// {@macro state}
  CentrifugeState$Connecting({required this.url, DateTime? timestamp})
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
    required CentrifugeStateMatch<R, CentrifugeState$Disconnected> disconnected,
    required CentrifugeStateMatch<R, CentrifugeState$Connecting> connecting,
    required CentrifugeStateMatch<R, CentrifugeState$Connected> connected,
    required CentrifugeStateMatch<R, CentrifugeState$Closed> closed,
  }) =>
      connecting(this);

  @override
  int get hashCode => 1;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CentrifugeState$Connecting &&
          other.timestamp.isAtSameMomentAs(timestamp));

  @override
  String toString() => 'CentrifugeState.connecting{$timestamp}';
}

/// Connected
///
/// {@macro state}
final class CentrifugeState$Connected extends CentrifugeState
    with _$CentrifugeState {
  /// Connected
  ///
  /// {@macro state}
  CentrifugeState$Connected({
    required this.url,
    DateTime? timestamp,
    this.client,
    this.version,
    this.ttl,
    this.expires,
    this.pingInterval,
    this.sendPong,
    this.session,
    this.node,
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
  final bool? expires;

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
    required CentrifugeStateMatch<R, CentrifugeState$Disconnected> disconnected,
    required CentrifugeStateMatch<R, CentrifugeState$Connecting> connecting,
    required CentrifugeStateMatch<R, CentrifugeState$Connected> connected,
    required CentrifugeStateMatch<R, CentrifugeState$Closed> closed,
  }) =>
      connected(this);

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        ...super.toJson(),
        if (client != null) 'client': client,
        if (version != null) 'version': version,
        if (expires != null) 'expires': expires,
        if (ttl != null) 'ttl': ttl?.microsecondsSinceEpoch,
        if (pingInterval != null) 'pingInterval': pingInterval?.inSeconds,
        if (sendPong != null) 'sendPong': sendPong,
        if (session != null) 'session': session,
        if (node != null) 'node': node,
      };

  @override
  int get hashCode => 2;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CentrifugeState$Connected &&
          other.timestamp.isAtSameMomentAs(timestamp));

  @override
  String toString() => 'CentrifugeState.connected{$timestamp}';
}

/// Permanently closed
///
/// {@macro state}
final class CentrifugeState$Closed extends CentrifugeState
    with _$CentrifugeState {
  /// Permanently closed
  ///
  /// {@macro state}
  CentrifugeState$Closed({DateTime? timestamp})
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
    required CentrifugeStateMatch<R, CentrifugeState$Disconnected> disconnected,
    required CentrifugeStateMatch<R, CentrifugeState$Connecting> connecting,
    required CentrifugeStateMatch<R, CentrifugeState$Connected> connected,
    required CentrifugeStateMatch<R, CentrifugeState$Closed> closed,
  }) =>
      closed(this);

  @override
  int get hashCode => 3;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CentrifugeState$Closed &&
          other.timestamp.isAtSameMomentAs(timestamp));

  @override
  String toString() => 'CentrifugeState.closed{$timestamp}';
}

/// {@nodoc}
base mixin _$CentrifugeState on CentrifugeState {}

/// Pattern matching for [CentrifugeState].
typedef CentrifugeStateMatch<R, S extends CentrifugeState> = R Function(
    S state);

/// {@nodoc}
@immutable
abstract base class _$CentrifugeStateBase {
  /// {@nodoc}
  const _$CentrifugeStateBase(this.timestamp);

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

  /// Pattern matching for [CentrifugeState].
  R map<R>({
    required CentrifugeStateMatch<R, CentrifugeState$Disconnected> disconnected,
    required CentrifugeStateMatch<R, CentrifugeState$Connecting> connecting,
    required CentrifugeStateMatch<R, CentrifugeState$Connected> connected,
    required CentrifugeStateMatch<R, CentrifugeState$Closed> closed,
  });

  /// Pattern matching for [CentrifugeState].
  R maybeMap<R>({
    required R Function() orElse,
    CentrifugeStateMatch<R, CentrifugeState$Disconnected>? disconnected,
    CentrifugeStateMatch<R, CentrifugeState$Connecting>? connecting,
    CentrifugeStateMatch<R, CentrifugeState$Connected>? connected,
    CentrifugeStateMatch<R, CentrifugeState$Closed>? closed,
  }) =>
      map<R>(
        disconnected: disconnected ?? (_) => orElse(),
        connecting: connecting ?? (_) => orElse(),
        connected: connected ?? (_) => orElse(),
        closed: closed ?? (_) => orElse(),
      );

  /// Pattern matching for [CentrifugeState].
  R? mapOrNull<R>({
    CentrifugeStateMatch<R, CentrifugeState$Disconnected>? disconnected,
    CentrifugeStateMatch<R, CentrifugeState$Connecting>? connecting,
    CentrifugeStateMatch<R, CentrifugeState$Connected>? connected,
    CentrifugeStateMatch<R, CentrifugeState$Closed>? closed,
  }) =>
      map<R?>(
        disconnected: disconnected ?? (_) => null,
        connecting: connecting ?? (_) => null,
        connected: connected ?? (_) => null,
        closed: closed ?? (_) => null,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'type': type,
        'timestamp': timestamp.microsecondsSinceEpoch,
        if (url != null) 'url': url,
      };
}
