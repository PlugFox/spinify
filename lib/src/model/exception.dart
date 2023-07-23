import 'package:centrifuge_dart/interface.dart';
import 'package:meta/meta.dart';

/// {@template exception}
/// Centrifuge exception.
/// {@endtemplate}
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
final class CentrifugeConnectionException extends CentrifugeException {
  /// {@macro exception}
  const CentrifugeConnectionException([Object? error])
      : super(
          'centrifuge_connection_exception',
          'Connection problem',
          error,
        );
}

/// {@macro exception}
final class CentrifugeDisconnectionException extends CentrifugeException {
  /// {@macro exception}
  const CentrifugeDisconnectionException([Object? error])
      : super(
          'centrifuge_disconnection_exception',
          'Connection problem',
          error,
        );
}

/// {@macro exception}
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
final class CentrifugeSubscriptionException extends CentrifugeException {
  /// {@macro exception}
  const CentrifugeSubscriptionException({
    required this.subscription,
    required String message,
    Object? error,
  }) : super(
          'centrifuge_subscription_exception',
          message,
          error,
        );

  /// Subscription
  final ICentrifugeSubscription subscription;
}
