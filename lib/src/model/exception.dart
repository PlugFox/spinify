import 'package:meta/meta.dart';

/// {@template exception}
/// Spinify exception.
/// {@endtemplate}
/// {@category Exception}
@immutable
sealed class SpinifyException implements Exception {
  /// {@macro exception}
  const SpinifyException(
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

  /// Visitor pattern for nested exceptions.
  /// Callback for each nested exception, starting from the current one.
  void visitor(void Function(Object error) fn) {
    fn(this);
    switch (error) {
      case SpinifyException e:
        e.visitor(fn);
      case Object e:
        fn(e);
      case null:
        break;
    }
  }

  @override
  int get hashCode => code.hashCode;

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  String toString() => message;
}

/// {@macro exception}
/// {@category Exception}
final class SpinifyConnectionException extends SpinifyException {
  /// {@macro exception}
  const SpinifyConnectionException({String? message, Object? error})
      : super(
          'spinify_connection_exception',
          message ?? 'Connection problem',
          error,
        );
}

/// {@macro exception}
/// {@category Exception}
final class SpinifyReplyException extends SpinifyException {
  /// {@macro exception}
  const SpinifyReplyException({
    required this.replyCode,
    required String replyMessage,
    required this.temporary,
  }) : super(
          'spinify_reply_exception',
          replyMessage,
        );

  /// Reply code.
  final int replyCode;

  /// Is reply error final.
  final bool temporary;
}

/// {@macro exception}
/// {@category Exception}
final class SpinifyPingException extends SpinifyException {
  /// {@macro exception}
  const SpinifyPingException([Object? error])
      : super(
          'spinify_ping_exception',
          'Ping error',
          error,
        );
}

/// {@macro exception}
/// {@category Exception}
final class SpinifySubscriptionException extends SpinifyException {
  /// {@macro exception}
  const SpinifySubscriptionException({
    required this.channel,
    required String message,
    Object? error,
  }) : super(
          'spinify_subscription_exception',
          message,
          error,
        );

  /// Subscription channel.
  final String channel;
}

/// {@macro exception}
/// {@category Exception}
final class SpinifySendException extends SpinifyException {
  /// {@macro exception}
  const SpinifySendException({
    String? message,
    Object? error,
  }) : super(
          'spinify_send_exception',
          message ?? 'Failed to send message',
          error,
        );
}

/// {@macro exception}
/// {@category Exception}
final class SpinifyFetchException extends SpinifyException {
  /// {@macro exception}
  const SpinifyFetchException({
    String? message,
    Object? error,
  }) : super(
          'spinify_fetch_exception',
          message ?? 'Failed to fetch data',
          error,
        );
}

/// {@macro exception}
/// {@category Exception}
final class SpinifyRefreshException extends SpinifyException {
  /// {@macro exception}
  const SpinifyRefreshException({
    String? message,
    Object? error,
  }) : super(
          'spinify_refresh_exception',
          message ?? 'Error while refreshing connection token',
          error,
        );
}
