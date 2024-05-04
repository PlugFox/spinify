/// Server may send custom disconnect codes to a client.
/// Custom disconnect codes must be in range [3000, 4999].
///
/// Client automatically reconnects upon receiving code
/// in range 3000-3499, 4000-4499
/// (i.e. Client goes to connecting state).
/// Other codes result into going to disconnected state.
///
/// Client implementation can use codes < 3000 for client-side
/// specific disconnect reasons.
sealed class SpinifyDisconnectedCode {
  /// Disconnect called.
  static const int disconnectCalled = 0;

  /// Connection closed by the server.
  static const int unauthorized = 1;

  /// Connection closed by the server.
  static const int badProtocol = 2;

  /// Connection closed by the server.
  static const int messageSizeLimit = 3;
}

/// Close code for connecting.
sealed class SpinifyConnectingCode {
  /// Connect called.
  static const int connectCalled = 0;

  /// Transport closed.
  static const int transportClosed = 1;

  /// No ping received.
  static const int noPing = 2;

  /// Subscribe timeout.
  static const int subscribeTimeout = 3;

  /// Unsubscribe timeout.
  static const int unsubscribeError = 4;
}

/// Close code for subscribing.
sealed class SpinifySubscribingCode {
  /// Subscribe called.
  static const int subscribeCalled = 0;

  /// Transport closed.
  static const int transportClosed = 1;
}

/// Close code for unsubscribing.
///
/// Server may return unsubscribe codes.
/// Server unsubscribe codes must be in range [2000, 2999].
///
/// Unsubscribe codes >= 2500 coming from server to client result
/// into automatic resubscribe attempt
/// (i.e. client goes to subscribing state).
/// Codes < 2500 result into going to unsubscribed state.
///
/// Client implementation can use codes < 2000 for client-side
/// specific unsubscribe reasons.
sealed class SpinifyUnsubscribedCode {
  /// Unsubscribe called.
  static const int unsubscribeCalled = 0;

  /// Unauthorized.
  static const int unauthorized = 1;

  /// Client closed.
  static const int clientClosed = 2;
}

/// Server can return error codes in range 100-1999.
/// Error codes in interval 0-399 reserved by Centrifuge/Centrifugo server.
/// Codes in range [400, 1999] may be returned by application code built
/// on top of Centrifuge/Centrifugo.
///
/// Server errors contain a temporary boolean flag which works as a signal
/// that error may be fixed by a later retry.
///
/// Errors with codes 0-100 can be used by client-side implementation.
/// Client-side errors may not have code attached at all since in many
/// languages error can be distinguished by its type.
sealed class SpinifyErrorCode {}
