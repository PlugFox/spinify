import 'package:meta/meta.dart';

/// Unsubscribe codes.
@internal
enum UnsubscribeCode {
  /// Disconnect called
  unsubscribeCalled(0, 'unsubscribe called'),

  /// Unauthorized
  unauthorized(1, 'unauthorized'),

  /// Client closed
  clientClosed(2, 'client closed');

  const UnsubscribeCode(this.code, this.reason);

  /// Unsubscribe code.
  final int code;

  /// Unsubscribe reason.
  final String reason;
}
