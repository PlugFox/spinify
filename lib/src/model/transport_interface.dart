import 'command.dart';
import 'config.dart';
import 'reply.dart';

/// Create a Spinify transport
/// (e.g. WebSocket or gRPC with JSON or Protocol Buffers).
typedef CreateSpinifyTransport = Future<ISpinifyTransport> Function(
  /// URL for the connection
  String url,

  /// Spinify client configuration
  SpinifyConfig config,
);

/// Spinify transport interface.
abstract interface class ISpinifyTransport {
  /// Send command to the server.
  Future<void> send(SpinifyCommand command);

  /// Set handler for [SpinifyReply] messages.
  // ignore: avoid_setters_without_getters
  set onReply(void Function(SpinifyReply reply) handler);

  /// Set handler for connection close event.
  // ignore: avoid_setters_without_getters
  set onDisconnect(void Function() handler);

  /// Disconnect from the server.
  /// Client if not needed anymore.
  Future<void> disconnect([int? code, String? reason]);
}
