// coverage:ignore-file
import 'package:meta/meta.dart';

import 'model/config.dart';
import 'model/metric.dart';
import 'model/reply.dart';
import 'model/transport_interface.dart';

/// Create a WebSocket Protocol Buffers transport.
@internal
Future<ISpinifyTransport> $create$WS$PB$Transport({
  /// URL for the connection
  required String url,

  /// Spinify client configuration
  required SpinifyConfig config,

  /// Metrics
  required SpinifyMetrics$Mutable metrics,

  /// Callback for reply messages
  required void Function(SpinifyReply reply) onReply,

  /// Callback for disconnect event
  required void Function({required bool temporary}) onDisconnect,
}) =>
    throw UnimplementedError();
