import 'package:meta/meta.dart';

/// {@template exception}
/// Centrifuge exception.
/// {@endtemplate}
/// {@category Exception}
@immutable
sealed class CentrifugeException implements Exception {
  /// {@macro exception}
  const CentrifugeException(
    this.code,
    this.message, [
    this.error,
  ]);

  /// Error code.
  final String code;

  /// Error message.
  final String message;

  /// Source error of exception if exists.
  final Object? error;

  @override
  int get hashCode => code.hashCode;

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  String toString() => message;
}

/// {@macro exception}
/// {@category Exception}
final class CentrifugeConnectionException extends CentrifugeException {
  /// {@macro exception}
  const CentrifugeConnectionException({String? message, Object? error})
      : super(
          'centrifuge_disconnection_exception',
          message ?? 'Connection problem',
          error,
        );
}

/// {@macro exception}
/// {@category Exception}
final class CentrifugeReplyException extends CentrifugeException {
  /// {@macro exception}
  const CentrifugeReplyException({
    required this.replyCode,
    required String replyMessage,
    required this.temporary,
  }) : super(
          'centrifuge_reply_exception',
          replyMessage,
        );

  /// Reply code.
  final int replyCode;

  /// Is reply error final.
  final bool temporary;
}

/// {@macro exception}
/// {@category Exception}
final class CentrifugePingException extends CentrifugeException {
  /// {@macro exception}
  const CentrifugePingException([Object? error])
      : super(
          'centrifuge_ping_exception',
          'Ping error',
          error,
        );
}

/// {@macro exception}
/// {@category Exception}
final class CentrifugeSubscriptionException extends CentrifugeException {
  /// {@macro exception}
  const CentrifugeSubscriptionException({
    required this.channel,
    required String message,
    Object? error,
  }) : super(
          'centrifuge_subscription_exception',
          message,
          error,
        );

  /// Subscription channel.
  final String channel;
}

/// {@macro exception}
/// {@category Exception}
final class CentrifugeSendException extends CentrifugeException {
  /// {@macro exception}
  const CentrifugeSendException({
    String? message,
    Object? error,
  }) : super(
          'centrifuge_send_exception',
          message ?? 'Failed to send message',
          error,
        );
}
