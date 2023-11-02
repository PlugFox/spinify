import 'package:meta/meta.dart';

/// {@template chat_connection_state}
/// ChatConnectionState.
/// {@endtemplate}
sealed class ChatConnectionState extends _$ChatConnectionStateBase {
  /// Disconnected
  /// {@macro chat_connection_state}
  const factory ChatConnectionState.disconnected({
    String message,
  }) = ChatConnectionState$Disconnected;

  /// Connecting
  /// {@macro chat_connection_state}
  const factory ChatConnectionState.connecting({
    String message,
  }) = ChatConnectionState$Connecting;

  /// Connected
  /// {@macro chat_connection_state}
  const factory ChatConnectionState.connected({
    String message,
  }) = ChatConnectionState$Connected;

  /// {@macro chat_connection_state}
  const ChatConnectionState({required super.message});
}

/// Disconnected
/// {@nodoc}
final class ChatConnectionState$Disconnected extends ChatConnectionState {
  /// {@nodoc}
  const ChatConnectionState$Disconnected({super.message = 'Disconnected'});
}

/// Connecting
/// {@nodoc}
final class ChatConnectionState$Connecting extends ChatConnectionState {
  /// {@nodoc}
  const ChatConnectionState$Connecting({super.message = 'Connecting'});
}

/// Connected
/// {@nodoc}
final class ChatConnectionState$Connected extends ChatConnectionState {
  /// {@nodoc}
  const ChatConnectionState$Connected({super.message = 'Connected'});
}

/// Pattern matching for [ChatConnectionState].
typedef ChatConnectionStateMatch<R, S extends ChatConnectionState> = R Function(
    S state);

/// {@nodoc}
@immutable
abstract base class _$ChatConnectionStateBase {
  /// {@nodoc}
  const _$ChatConnectionStateBase({required this.message});

  /// Message or state description.
  @nonVirtual
  final String message;

  /// Is connecting?
  bool get isConnecting =>
      maybeMap<bool>(orElse: () => false, connecting: (_) => true);

  /// Is connected?
  bool get isConnected =>
      maybeMap<bool>(orElse: () => false, connected: (_) => true);

  /// Is disconnected?
  bool get isDisconnected =>
      maybeMap<bool>(orElse: () => false, disconnected: (_) => true);

  /// Pattern matching for [ChatConnectionState].
  R map<R>({
    required ChatConnectionStateMatch<R, ChatConnectionState$Disconnected>
        disconnected,
    required ChatConnectionStateMatch<R, ChatConnectionState$Connecting>
        connecting,
    required ChatConnectionStateMatch<R, ChatConnectionState$Connected>
        connected,
  }) =>
      switch (this) {
        ChatConnectionState$Disconnected s => disconnected(s),
        ChatConnectionState$Connecting s => connecting(s),
        ChatConnectionState$Connected s => connected(s),
        _ => throw AssertionError(),
      };

  /// Pattern matching for [ChatConnectionState].
  R maybeMap<R>({
    ChatConnectionStateMatch<R, ChatConnectionState$Disconnected>? disconnected,
    ChatConnectionStateMatch<R, ChatConnectionState$Connecting>? connecting,
    ChatConnectionStateMatch<R, ChatConnectionState$Connected>? connected,
    required R Function() orElse,
  }) =>
      map<R>(
        disconnected: disconnected ?? (_) => orElse(),
        connecting: connecting ?? (_) => orElse(),
        connected: connected ?? (_) => orElse(),
      );

  /// Pattern matching for [ChatConnectionState].
  R? mapOrNull<R>({
    ChatConnectionStateMatch<R, ChatConnectionState$Disconnected>? disconnected,
    ChatConnectionStateMatch<R, ChatConnectionState$Connecting>? connecting,
    ChatConnectionStateMatch<R, ChatConnectionState$Connected>? connected,
  }) =>
      map<R?>(
        disconnected: disconnected ?? (_) => null,
        connecting: connecting ?? (_) => null,
        connected: connected ?? (_) => null,
      );

  @override
  String toString() => message;
}
