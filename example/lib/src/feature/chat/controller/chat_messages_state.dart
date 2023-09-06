import 'package:meta/meta.dart';
import 'package:spinifyapp/src/feature/chat/model/message.dart';

/// Chat messages entity.
typedef ChatMessages = List<Message>;

/// {@template chat_messages_state}
/// ChatMessagesState.
/// {@endtemplate}
sealed class ChatMessagesState extends _$ChatMessagesStateBase {
  /// Idling state
  /// {@macro chat_messages_state}
  const factory ChatMessagesState.idle({
    required ChatMessages data,
    String message,
  }) = ChatMessagesState$Idle;

  /// Processing
  /// {@macro chat_messages_state}
  const factory ChatMessagesState.processing({
    required ChatMessages data,
    String message,
  }) = ChatMessagesState$Processing;

  /// Successful
  /// {@macro chat_messages_state}
  const factory ChatMessagesState.successful({
    required ChatMessages data,
    String message,
  }) = ChatMessagesState$Successful;

  /// An error has occurred
  /// {@macro chat_messages_state}
  const factory ChatMessagesState.error({
    required ChatMessages data,
    String message,
  }) = ChatMessagesState$Error;

  /// {@macro chat_messages_state}
  const ChatMessagesState({required super.data, required super.message});

  static ChatMessagesState get initial =>
      const ChatMessagesState.idle(data: <Message>[]);
}

/// Idling state
/// {@nodoc}
final class ChatMessagesState$Idle extends ChatMessagesState {
  /// {@nodoc}
  const ChatMessagesState$Idle({required super.data, super.message = 'Idling'});

  @override
  ChatMessagesState$Idle copyWith({
    ChatMessages? data,
    String? message,
  }) =>
      ChatMessagesState$Idle(
        data: data ?? this.data,
        message: message ?? this.message,
      );
}

/// Processing
/// {@nodoc}
final class ChatMessagesState$Processing extends ChatMessagesState {
  /// {@nodoc}
  const ChatMessagesState$Processing(
      {required super.data, super.message = 'Processing'});

  @override
  ChatMessagesState$Processing copyWith({
    ChatMessages? data,
    String? message,
  }) =>
      ChatMessagesState$Processing(
        data: data ?? this.data,
        message: message ?? this.message,
      );
}

/// Successful
/// {@nodoc}
final class ChatMessagesState$Successful extends ChatMessagesState {
  /// {@nodoc}
  const ChatMessagesState$Successful(
      {required super.data, super.message = 'Successful'});

  @override
  ChatMessagesState$Successful copyWith({
    ChatMessages? data,
    String? message,
  }) =>
      ChatMessagesState$Successful(
        data: data ?? this.data,
        message: message ?? this.message,
      );
}

/// Error
/// {@nodoc}
final class ChatMessagesState$Error extends ChatMessagesState {
  /// {@nodoc}
  const ChatMessagesState$Error(
      {required super.data, super.message = 'An error has occurred.'});

  @override
  ChatMessagesState$Error copyWith({
    ChatMessages? data,
    String? message,
  }) =>
      ChatMessagesState$Error(
        data: data ?? this.data,
        message: message ?? this.message,
      );
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
  final ChatMessages data;

  /// Message or state description.
  @nonVirtual
  final String message;

  /// If an error has occurred?
  bool get hasError => maybeMap<bool>(orElse: () => false, error: (_) => true);

  /// Is in progress state?
  bool get isProcessing =>
      maybeMap<bool>(orElse: () => false, processing: (_) => true);

  /// Is in idle state?
  bool get isIdling => !isProcessing;

  /// Copy with new data.
  ChatMessagesState copyWith({
    ChatMessages? data,
    String? message,
  });

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
