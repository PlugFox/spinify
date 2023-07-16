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
  factory CentrifugeState.disconnected({DateTime? timestamp}) =
      CentrifugeState$Disconnected;

  /// Connecting
  /// {@macro state}
  factory CentrifugeState.connecting(
      {required String url, DateTime? timestamp}) = CentrifugeState$Connecting;

  /// Connected
  /// {@macro state}
  factory CentrifugeState.connected(
      {required String url, DateTime? timestamp}) = CentrifugeState$Connected;

  /// Closed
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
          ),
        ('connecting', int timestamp, String url) => CentrifugeState.connecting(
            url: url,
            timestamp: DateTime.fromMicrosecondsSinceEpoch(timestamp),
          ),
        ('connected', int timestamp, String url) => CentrifugeState.connected(
            url: url,
            timestamp: DateTime.fromMicrosecondsSinceEpoch(timestamp),
          ),
        ('closed', int timestamp, _) => CentrifugeState.closed(
            timestamp: DateTime.fromMicrosecondsSinceEpoch(timestamp),
          ),
        _ => throw FormatException('Unknown state: $json'),
      };
}

/// Disconnected
///
/// {@macro state}
final class CentrifugeState$Disconnected extends CentrifugeState
    with _$CentrifugeState {
  /// Disconnected
  ///
  /// {@macro state}
  CentrifugeState$Disconnected({DateTime? timestamp})
      : super(timestamp ?? DateTime.now());

  @override
  String get type => 'disconnected';

  @override
  String? get url => null;

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
  CentrifugeState$Connected({required this.url, DateTime? timestamp})
      : super(timestamp ?? DateTime.now());

  @override
  String get type => 'connected';

  @override
  final String url;

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
  int get hashCode => 2;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CentrifugeState$Connected &&
          other.timestamp.isAtSameMomentAs(timestamp));

  @override
  String toString() => 'CentrifugeState.connected{$timestamp}';
}

/// Closed
///
/// {@macro state}
final class CentrifugeState$Closed extends CentrifugeState
    with _$CentrifugeState {
  /// Closed
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
