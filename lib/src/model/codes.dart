import 'package:meta/meta.dart';

/// The disconnect codes for the Spinify WebSocket connection.
///
/// Codes have some rules which should be followed by a client
/// connector implementation.
/// These rules described below.
///
/// Codes in range 0..2999 should not be used by a Centrifuge library user.
/// Those are reserved for the client-side and transport specific needs.
///
/// Server may send custom disconnect codes to a client.
/// Custom disconnect codes must be in range 3000..4999.
///
/// Codes in range >=5000 should not be used also.
/// Those are reserved by Centrifuge.
///
/// Client should reconnect upon receiving code in range
/// 3000..3499, 4000..4499, >=5000.
/// For codes <3000 reconnect behavior can be adjusted for specific transport.
/// (Default reconnect is true in this implementation).
///
/// Codes in range 3500..3999 and 4500..4999 are application terminal codes,
/// no automatic reconnect should be made by a client implementation.
///
/// Library users supposed to use codes in range 4000..4999 for creating custom
/// disconnects.
extension type const SpinifyDisconnectCode(int code) implements int {
  // --- 0..2999 Internal client-side and transport specific codes --- //

  /// Disconnect called explicitly by the client.
  @literal
  const SpinifyDisconnectCode.disconnect() : code = 0;

  /// Error Internal means server error,
  /// if returned this is a signal that something went wrong with the server
  /// itself and client is most probably not guilty.
  @literal
  const SpinifyDisconnectCode.internalServerError() : code = 100;

  /// Unauthorized indicates that the request is unauthorized.
  @literal
  const SpinifyDisconnectCode.unauthorized() : code = 101;

  /// Unknown Channel means that the channel name does not exist.
  /// Usually this is returned when client uses a channel with a namespace
  /// that is not defined in the Centrifugo configuration.
  @literal
  const SpinifyDisconnectCode.unknownChannel() : code = 102;

  /// Permission Denied means access to the resource is not allowed.
  @literal
  const SpinifyDisconnectCode.permissionDenied() : code = 103;

  /// Method Not Found indicates that the requested method does not exist.
  @literal
  const SpinifyDisconnectCode.methodNotFound() : code = 104;

  /// Already Subscribed indicates that the client is already subscribed
  /// to the specified channel. In Centrifugo, a client can only have one
  /// subscription to a specific channel.
  @literal
  const SpinifyDisconnectCode.alreadySubscribed() : code = 105;

  /// Limit Exceeded indicates that a server-imposed
  /// limit has been exceeded.
  /// Server logs should provide more information.
  @literal
  const SpinifyDisconnectCode.limitExceeded() : code = 106;

  /// Bad Request means the server cannot process the received data
  /// because it is malformed. Retrying the request does not make sense.
  @literal
  const SpinifyDisconnectCode.badRequest() : code = 107;

  /// Not Available indicates that the requested resource is not enabled.
  /// This may occur, for example, when trying to access history or presence
  /// in a channel that does not support these features.
  @literal
  const SpinifyDisconnectCode.notAvailable() : code = 108;

  /// Token Expired indicates that the connection token has expired.
  /// This is generally handled by updating the token.
  @literal
  const SpinifyDisconnectCode.tokenExpired() : code = 109;

  /// Expired indicates that the connection has expired
  /// (no token involved).
  @literal
  const SpinifyDisconnectCode.expired() : code = 110;

  /// Too Many Requests means that the server rejected the request
  /// due to rate limiting.
  @literal
  const SpinifyDisconnectCode.tooManyRequests() : code = 111;

  /// Unrecoverable Position indicates that the stream does not contain
  /// the required range of publications to fulfill a history query, possibly
  /// due to an incorrect epoch being passed.
  @literal
  const SpinifyDisconnectCode.unrecoverablePosition() : code = 112;

  /// Normalize disconnect code and reason.
  @experimental
  static ({SpinifyDisconnectCode code, String reason, bool reconnect})
      normalize([int? code, String? reason]) => switch (code ?? 1) {
            // --- Client error codes --- //

            /// Disconnect called explicitly by the client.
            0 => (
                code: const SpinifyDisconnectCode(0),
                reason: reason ?? 'disconnect called',
                reconnect: true,
              ),

            /// Disconnect due to malformed protocol message sent by the client.
            2 => (
                code: const SpinifyDisconnectCode(2),
                reason: reason ?? 'bad protocol',
                reconnect: true,
              ),

            /// Internal server error means server error,
            /// if returned this is a signal that something went wrong with
            /// the server itself and client is most probably not guilty.
            100 => (
                code: const SpinifyDisconnectCode(100),
                reason: reason ?? 'internal server error',
                reconnect: true,
              ),

            /// Unauthorized indicates that the request is unauthorized.
            101 => (
                code: const SpinifyDisconnectCode(101),
                reason: reason ?? 'unauthorized',
                reconnect: true,
              ),

            /// Unknown Channel means that the channel name does not exist.
            /// Usually this is returned when the client uses a channel with a
            /// namespace that is not defined in Centrifugo configuration.
            102 => (
                code: const SpinifyDisconnectCode(102),
                reason: reason ?? 'unknown channel',
                reconnect: true,
              ),

            /// Permission Denied means access to the resource is not allowed.
            103 => (
                code: const SpinifyDisconnectCode(103),
                reason: reason ?? 'permission denied',
                reconnect: true,
              ),

            /// Method Not Found indicates that
            /// the requested method does not exist.
            104 => (
                code: const SpinifyDisconnectCode(104),
                reason: reason ?? 'method not found',
                reconnect: true,
              ),

            /// Already Subscribed indicates that the client is
            ///  already subscribed to the specified channel.
            /// In Centrifugo, a client can only have one
            /// subscription to a specific channel.
            105 => (
                code: const SpinifyDisconnectCode(105),
                reason: reason ?? 'already subscribed',
                reconnect: true,
              ),

            /// Limit Exceeded indicates that a server-imposed
            /// limit has been exceeded.
            /// Server logs should provide more information.
            106 => (
                code: const SpinifyDisconnectCode(106),
                reason: reason ?? 'limit exceeded',
                reconnect: true,
              ),

            /// Bad Request means the server cannot process the received data
            /// because it is malformed.
            /// Retrying the request does not make sense.
            107 => (
                code: const SpinifyDisconnectCode(107),
                reason: reason ?? 'bad request',
                reconnect: true,
              ),

            /// Not Available indicates that the requested
            /// resource is not enabled.
            /// This may occur, for example,
            /// when trying to access history or presence
            /// in a channel that does not support these features.
            108 => (
                code: const SpinifyDisconnectCode(108),
                reason: reason ?? 'not available',
                reconnect: true,
              ),

            /// Token Expired indicates that the connection token has expired.
            /// This is generally handled by updating the token.
            109 => (
                code: const SpinifyDisconnectCode(109),
                reason: reason ?? 'token expired',
                reconnect: true,
              ),

            /// Expired indicates that the connection has expired
            /// (no token involved).
            110 => (
                code: const SpinifyDisconnectCode(110),
                reason: reason ?? 'expired',
                reconnect: true,
              ),

            /// Too Many Requests means that the server rejected the request
            /// due to rate limiting.
            111 => (
                code: const SpinifyDisconnectCode(111),
                reason: reason ?? 'too many requests',
                reconnect: true,
              ),

            /// Unrecoverable Position indicates that
            /// the stream does not contain
            /// the required range of publications to fulfill a history query,
            /// possibly due to an incorrect epoch being passed.
            112 => (
                code: const SpinifyDisconnectCode(112),
                reason: reason ?? 'unrecoverable position',
                reconnect: true,
              ),

            /// Message size limit exceeded.
            1009 => (
                code: const SpinifyDisconnectCode(1009),
                reason: reason ?? 'message size limit exceeded',
                reconnect: true,
              ),

            /// Custom disconnect codes from server.
            /// We expose codes defined by Centrifuge protocol,
            /// hiding details about transport-specific error codes.
            /// Reconnect is true by default.
            < 3000 => (
                code: SpinifyDisconnectCode(code ?? 0),
                reason: reason ?? 'transport closed',
                reconnect: true,
              ),

            // --- Non-terminal disconnect codes --- //

            /// DisconnectConnectionClosed is a special Disconnect
            /// object used when
            /// client connection was closed without any advice
            /// from a server side.
            /// This can be a clean disconnect,
            /// or temporary disconnect of the client
            /// due to internet connection loss.
            /// Server can not distinguish the actual reason of disconnect.
            3000 => (
                code: const SpinifyDisconnectCode(3000),
                reason: reason ?? 'connection closed',
                reconnect: true,
              ),

            /// Shutdown code.
            3001 => (
                code: const SpinifyDisconnectCode(3001),
                reason: reason ?? 'shutdown',
                reconnect: true,
              ),

            /// DisconnectServerError issued when
            /// internal error occurred on server.
            3004 => (
                code: const SpinifyDisconnectCode(3004),
                reason: reason ?? 'internal server error',
                reconnect: true,
              ),

            /// DisconnectExpired
            3005 => (
                code: const SpinifyDisconnectCode(3005),
                reason: reason ?? 'connection expired',
                reconnect: true,
              ),

            /// DisconnectSubExpired issued when client subscription expired.
            3006 => (
                code: const SpinifyDisconnectCode(3006),
                reason: reason ?? 'subscription expired',
                reconnect: true,
              ),

            /// DisconnectSlow issued when client
            /// can't read messages fast enough.
            3008 => (
                code: const SpinifyDisconnectCode(3008),
                reason: reason ?? 'slow',
                reconnect: true,
              ),

            /// DisconnectWriteError issued when an error occurred
            /// while writing to client connection.
            3009 => (
                code: const SpinifyDisconnectCode(3009),
                reason: reason ?? 'write error',
                reconnect: true,
              ),

            /// DisconnectInsufficientState issued when Centrifugo detects wrong
            /// client position in a channel stream.
            /// Disconnect allows client to restore missed
            /// publications on reconnect.
            ///
            /// Insufficient state in channel only happens in channels
            /// with positioning/recovery on – where Centrifugo detects message
            /// loss and message order issues.
            ///
            /// Insufficient state in a stream means that Centrifugo
            /// detected message loss from the broker.
            /// Generally, rare cases of getting such disconnect code are OK,
            /// but if there is an increase in the amount of such codes
            /// – then this can be a signal of Centrifugo-to-Broker
            /// communication issue. The root cause should be investigated –
            /// it may be an unstable connection between Centrifugo and broker,
            /// or Centrifugo can't keep up with a message stream in a channel,
            /// or a broker skips messages for some reason.
            3010 => (
                code: const SpinifyDisconnectCode(3010),
                reason: reason ?? 'insufficient state',
                reconnect: true,
              ),

            /// DisconnectForceReconnect issued when server disconnects
            /// connection for some reason and whants it to reconnect.
            3011 => (
                code: const SpinifyDisconnectCode(3011),
                reason: reason ?? 'force reconnect',
                reconnect: true,
              ),

            /// DisconnectNoPong may be issued when server disconnects
            /// bidirectional connection due to no pong received to
            /// application-level server-to-client pings in a configured time.
            3012 => (
                code: const SpinifyDisconnectCode(3012),
                reason: reason ?? 'no pong',
                reconnect: true,
              ),

            /// DisconnectTooManyRequests may be issued when client sends
            /// too many commands to a server.
            3013 => (
                code: const SpinifyDisconnectCode(3013),
                reason: reason ?? 'too many requests',
                reconnect: true,
              ),

            /// Custom disconnect codes from server.
            /// Reconnect is true by default.
            <= 3499 => (
                code: SpinifyDisconnectCode(code ?? 0),
                reason: reason ?? 'transport closed',
                reconnect: true,
              ),

            // --- Terminal disconnect codes --- //

            /// DisconnectInvalidToken issued when client
            /// came with invalid token.
            3500 => (
                code: const SpinifyDisconnectCode(3500),
                reason: reason ?? 'invalid token',
                reconnect: false,
              ),

            /// DisconnectBadRequest issued when client
            /// uses malformed protocol frames.
            3501 => (
                code: const SpinifyDisconnectCode(3501),
                reason: reason ?? 'bad request',
                reconnect: false,
              ),

            /// DisconnectStale issued to close connection that did not become
            /// authenticated in configured interval after dialing.
            3502 => (
                code: const SpinifyDisconnectCode(3502),
                reason: reason ?? 'stale',
                reconnect: false,
              ),

            /// DisconnectForceNoReconnect issued when server
            /// disconnects connection and asks it to not reconnect again.
            3503 => (
                code: const SpinifyDisconnectCode(3503),
                reason: reason ?? 'force disconnect',
                reconnect: false,
              ),

            /// DisconnectConnectionLimit can be issued when client connection
            /// exceeds a configured connection limit
            /// (per user ID or due to other rule).
            3504 => (
                code: const SpinifyDisconnectCode(3504),
                reason: reason ?? 'connection limit',
                reconnect: false,
              ),

            /// DisconnectChannelLimit can be issued when client
            /// connection exceeds a configured channel limit.
            3505 => (
                code: const SpinifyDisconnectCode(3505),
                reason: reason ?? 'channel limit',
                reconnect: false,
              ),

            /// DisconnectInappropriateProtocol can be issued when
            /// client connection format can not handle incoming data.
            /// For example, this happens when JSON-based clients receive
            /// binary data in a channel.
            /// This is usually an indicator of programmer error,
            /// JSON clients can not handle binary.
            3506 => (
                code: const SpinifyDisconnectCode(3506),
                reason: reason ?? 'inappropriate protocol',
                reconnect: false,
              ),

            /// DisconnectPermissionDenied may be issued when client
            /// attempts accessing a server without enough permissions.
            3507 => (
                code: const SpinifyDisconnectCode(3507),
                reason: reason ?? 'permission denied',
                reconnect: false,
              ),

            /// DisconnectNotAvailable may be issued when ErrorNotAvailable
            /// does not fit message type,
            /// for example we issue DisconnectNotAvailable
            /// when client sends asynchronous message without MessageHandler
            /// set on server side.
            3508 => (
                code: const SpinifyDisconnectCode(3508),
                reason: reason ?? 'not available',
                reconnect: false,
              ),

            /// DisconnectTooManyErrors may be issued when client
            /// generates too many errors.
            3509 => (
                code: const SpinifyDisconnectCode(3509),
                reason: reason ?? 'too many errors',
                reconnect: false,
              ),

            /// Application terminal codes with no reconnect.
            <= 3999 => (
                code: SpinifyDisconnectCode(code ?? 0),
                reason: reason ?? 'application terminal code',
                reconnect: false,
              ),

            /// Custom disconnect codes. Reconnect is true by default.
            <= 4499 => (
                code: SpinifyDisconnectCode(code ?? 0),
                reason: reason ?? 'transport closed',
                reconnect: true,
              ),

            /// Application terminal codes with no reconnect.
            <= 4999 => (
                code: SpinifyDisconnectCode(code ?? 0),
                reason: reason ?? 'application terminal code',
                reconnect: false,
              ),

            /// Internal and reserved by Centrifuge
            /// Reconnect is true by default.
            >= 5000 => (
                code: SpinifyDisconnectCode(code ?? 0),
                reason: reason ?? 'transport closed',
                reconnect: true,
              ),

            /// Custom disconnect codes.
            _ => (
                code: SpinifyDisconnectCode(code ?? 0),
                reason: reason ?? 'transport closed',
                reconnect: false,
              ),
          };

  /// Reconnect is needed due to specific transport close code.
  bool get reconnect => switch (code) {
        >= 0000 && <= 2999 => true, // Centrifuge library internal codes (true)
        >= 3000 && <= 3499 => true, // Server non-terminal codes (true)
        >= 3500 && <= 3999 => false, // Application terminal codes (false)
        >= 4000 && <= 4499 => true, // Custom disconnect codes (true)
        >= 4500 && <= 4999 => false, // Custom disconnect codes (false)
        >= 5000 => true, // Reserved by Centrifuge (true)
        _ => false, // Other cases (e.g. negative values)
      };
}
