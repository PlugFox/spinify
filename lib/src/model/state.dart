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
  factory SpinifyState.disconnected({DateTime? timestamp}) =
      SpinifyState$Disconnected;

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

  @override
  String toString() => type;
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
  }) : super(timestamp ?? DateTime.now());

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
    required SpinifyStateMatch<R, SpinifyState$Disconnected> disconnected,
    required SpinifyStateMatch<R, SpinifyState$Connecting> connecting,
    required SpinifyStateMatch<R, SpinifyState$Connected> connected,
    required SpinifyStateMatch<R, SpinifyState$Closed> closed,
  }) =>
      disconnected(this);

  @override
  int get hashCode => timestamp.millisecondsSinceEpoch * 10 + 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SpinifyState$Disconnected &&
          other.timestamp.isAtSameMomentAs(timestamp));
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
  int get hashCode => timestamp.millisecondsSinceEpoch * 10 + 1;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SpinifyState$Connecting &&
          other.timestamp.isAtSameMomentAs(timestamp));
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
  int get hashCode => timestamp.millisecondsSinceEpoch * 10 + 2;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SpinifyState$Connected &&
          other.timestamp.isAtSameMomentAs(timestamp));
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
  bool get isConnected => false;

  @override
  bool get isClosed => true;

  @override
  R map<R>({
    required SpinifyStateMatch<R, SpinifyState$Disconnected> disconnected,
    required SpinifyStateMatch<R, SpinifyState$Connecting> connecting,
    required SpinifyStateMatch<R, SpinifyState$Connected> connected,
    required SpinifyStateMatch<R, SpinifyState$Closed> closed,
  }) =>
      closed(this);

  @override
  int get hashCode => timestamp.millisecondsSinceEpoch * 10 + 3;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SpinifyState$Closed &&
          other.timestamp.isAtSameMomentAs(timestamp));
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
}
