import 'package:meta/meta.dart';

/// {@template chat_messages_state_placeholder}
/// Entity placeholder for ChatMessagesState
/// {@endtemplate}
typedef ChatMessagesEntity = Object;

/// {@template chat_messages_state}
/// ChatMessagesState.
/// {@endtemplate}
sealed class ChatMessagesState extends _$ChatMessagesStateBase {
  /// Idling state
  /// {@macro chat_messages_state}
  const factory ChatMessagesState.idle({
    required ChatMessagesEntity? data,
    String message,
  }) = ChatMessagesState$Idle;

  /// Processing
  /// {@macro chat_messages_state}
  const factory ChatMessagesState.processing({
    required ChatMessagesEntity? data,
    String message,
  }) = ChatMessagesState$Processing;

  /// Successful
  /// {@macro chat_messages_state}
  const factory ChatMessagesState.successful({
    required ChatMessagesEntity? data,
    String message,
  }) = ChatMessagesState$Successful;

  /// An error has occurred
  /// {@macro chat_messages_state}
  const factory ChatMessagesState.error({
    required ChatMessagesEntity? data,
    String message,
  }) = ChatMessagesState$Error;

  /// {@macro chat_messages_state}
  const ChatMessagesState({required super.data, required super.message});

  static ChatMessagesState get initial =>
      const ChatMessagesState.idle(data: null);
}

/// Idling state
/// {@nodoc}
final class ChatMessagesState$Idle extends ChatMessagesState {
  /// {@nodoc}
  const ChatMessagesState$Idle({required super.data, super.message = 'Idling'});
}

/// Processing
/// {@nodoc}
final class ChatMessagesState$Processing extends ChatMessagesState {
  /// {@nodoc}
  const ChatMessagesState$Processing(
      {required super.data, super.message = 'Processing'});
}

/// Successful
/// {@nodoc}
final class ChatMessagesState$Successful extends ChatMessagesState {
  /// {@nodoc}
  const ChatMessagesState$Successful(
      {required super.data, super.message = 'Successful'});
}

/// Error
/// {@nodoc}
final class ChatMessagesState$Error extends ChatMessagesState {
  /// {@nodoc}
  const ChatMessagesState$Error(
      {required super.data, super.message = 'An error has occurred.'});
}

/// Pattern matching for [ChatMessagesState].
typedef ChatMessagesStateMatch<R, S extends ChatMessagesState> = R Function(
    S state);

/// {@nodoc}
@immutable
abstract base class _$ChatMessagesStateBase {
  /// {@nodoc}
  const _$ChatMessagesStateBase({required this.data, required this.message});

  /// Data entity payload.
  @nonVirtual
  final ChatMessagesEntity? data;

  /// Message or state description.
  @nonVirtual
  final String message;

  /// Has data?
  bool get hasData => data != null;

  /// If an error has occurred?
  bool get hasError => maybeMap<bool>(orElse: () => false, error: (_) => true);

  /// Is in progress state?
  bool get isProcessing =>
      maybeMap<bool>(orElse: () => false, processing: (_) => true);

  /// Is in idle state?
  bool get isIdling => !isProcessing;

  /// Pattern matching for [ChatMessagesState].
  R map<R>({
    required ChatMessagesStateMatch<R, ChatMessagesState$Idle> idle,
    required ChatMessagesStateMatch<R, ChatMessagesState$Processing> processing,
    required ChatMessagesStateMatch<R, ChatMessagesState$Successful> successful,
    required ChatMessagesStateMatch<R, ChatMessagesState$Error> error,
  }) =>
      switch (this) {
        ChatMessagesState$Idle s => idle(s),
        ChatMessagesState$Processing s => processing(s),
        ChatMessagesState$Successful s => successful(s),
        ChatMessagesState$Error s => error(s),
        _ => throw AssertionError(),
      };

  /// Pattern matching for [ChatMessagesState].
  R maybeMap<R>({
    ChatMessagesStateMatch<R, ChatMessagesState$Idle>? idle,
    ChatMessagesStateMatch<R, ChatMessagesState$Processing>? processing,
    ChatMessagesStateMatch<R, ChatMessagesState$Successful>? successful,
    ChatMessagesStateMatch<R, ChatMessagesState$Error>? error,
    required R Function() orElse,
  }) =>
      map<R>(
        idle: idle ?? (_) => orElse(),
        processing: processing ?? (_) => orElse(),
        successful: successful ?? (_) => orElse(),
        error: error ?? (_) => orElse(),
      );

  /// Pattern matching for [ChatMessagesState].
  R? mapOrNull<R>({
    ChatMessagesStateMatch<R, ChatMessagesState$Idle>? idle,
    ChatMessagesStateMatch<R, ChatMessagesState$Processing>? processing,
    ChatMessagesStateMatch<R, ChatMessagesState$Successful>? successful,
    ChatMessagesStateMatch<R, ChatMessagesState$Error>? error,
  }) =>
      map<R?>(
        idle: idle ?? (_) => null,
        processing: processing ?? (_) => null,
        successful: successful ?? (_) => null,
        error: error ?? (_) => null,
      );

  @override
  int get hashCode => data.hashCode;

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  String toString() => 'ChatMessagesState(data: $data, message: $message)';
}
