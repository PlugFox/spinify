import 'package:meta/meta.dart';

/// {@template exception}
/// Centrifugo exception.
/// {@endtemplate}
@immutable
sealed class CentrifugoException {
  /// {@macro exception}
  const CentrifugoException(
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
  String toString() => 'CentrifugoException{code: $code}';
}

/// {@macro exception}
final class CentrifugoConnectionException extends CentrifugoException {
  /// {@macro exception}
  const CentrifugoConnectionException([Object? error])
      : super(
          'centrifugo_connection_exception',
          'Connection problem',
          error,
        );
}

/// {@macro exception}
final class CentrifugoDisconnectionException extends CentrifugoException {
  /// {@macro exception}
  const CentrifugoDisconnectionException([Object? error])
      : super(
          'centrifugo_disconnection_exception',
          'Connection problem',
          error,
        );
}
