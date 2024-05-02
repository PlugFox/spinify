import 'package:meta/meta.dart';

/// Disconnect codes.
///
/// Server may send custom disconnect codes to a client.
/// Custom disconnect codes must be in range [3000, 4999].
///
/// Client automatically reconnects upon receiving code
/// in range 3000-3499, 4000-4499 (i.e. Client goes to connecting state).
/// Other codes result into going to disconnected state.
///
/// Client implementation can use codes <3000 for client-side
/// specific disconnect reasons.
@internal
enum DisconnectCode {
  /// Disconnect called
  disconnectCalled(0, 'disconnect called'),

  /// Unauthorized
  unauthorized(1, 'unauthorized'),

  /// Bad protocol
  badProtocol(2, 'bad protocol'),

  /// Client message write error
  messageSizeLimit(3, 'message size limit exceeded'),

  /// Timeout
  timeout(4, 'timeout exceeded'),

  /// Unsubscribe error
  unsubscribeError(5, 'unsubscribe error');

  const DisconnectCode(this.code, this.reason);

  /// Disconnect code.
  final int code;

  /// Disconnect reason.
  final String reason;
}
