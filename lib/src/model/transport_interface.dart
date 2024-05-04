import 'command.dart';
import 'reply.dart';

/// Create a Spinify transport
/// (e.g. WebSocket or gRPC with JSON or Protocol Buffers).
typedef CreateSpinifyTransport = Future<ISpinifyTransport> Function(
  /// URL for the connection
  String url,

  /// Additional headers for the connection (optional)
  Map<String, String> headers,
);

/// Spinify transport interface.
abstract interface class ISpinifyTransport {
  /// Send command to the server.
  Future<void> send(SpinifyCommand command);

  /// Set handler for [SpinifyReply] messages.
  // ignore: avoid_setters_without_getters
  set onReply(void Function(SpinifyReply reply) handler);

  /// Disconnect from the server.
  /// Client if not needed anymore.
  Future<void> disconnect(int code, String reason);
}
