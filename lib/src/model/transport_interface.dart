import 'command.dart';
import 'config.dart';
import 'metric.dart';
import 'reply.dart';

/// Create a Spinify transport
/// (e.g. WebSocket or gRPC with JSON or Protocol Buffers).
typedef SpinifyTransportBuilder = Future<ISpinifyTransport> Function({
  /// URL for the connection
  required String url,

  /// Spinify client configuration
  required SpinifyConfig config,

  /// Metrics
  required SpinifyMetrics$Mutable metrics,

  /// Callback for reply messages
  required void Function(SpinifyReply reply) onReply,

  /// Callback for disconnect event
  required void Function() onDisconnect,
});

/// Spinify transport interface.
abstract interface class ISpinifyTransport {
  /// Send command to the server.
  Future<void> send(SpinifyCommand command);

  /// Disconnect from the server.
  /// Client if not needed anymore.
  Future<void> disconnect([int? code, String? reason]);
}
