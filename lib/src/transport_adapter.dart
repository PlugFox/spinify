import 'model/constant.dart';
import 'model/transport_interface.dart';
import 'web_socket_stub.dart'
    // ignore: uri_does_not_exist
    if (dart.library.js_interop) 'web_socket_js.dart'
    // ignore: uri_does_not_exist
    if (dart.library.io) 'web_socket_vm.dart';

/// Spinify transport adapter.
/// Allow to pass additional options for WebSocket connection.
final class SpinifyTransportAdapter {
  SpinifyTransportAdapter._({
    // Timeout for connection.
    Duration? timeout,
    // Callback called after connection established.
    void Function(WebSocket client)? afterConnect,
    // Additional list of protocols.
    Iterable<String>? protocols,
    // Binary type for JS platform (e.g. 'blob' or 'arraybuffer').
    String? binaryType,
    // Compression options for VM platform.
    Object? /*CompressionOptions*/ compression,
    // Custom HTTP client for VM platform.
    Object? /*HttpClient*/ customClient,
    // User agent for VM platform.
    String? userAgent,
  }) : _options = <String, Object?>{
          'timeout': timeout,
          'afterConnect': afterConnect,
          'protocols': protocols,
          if (kIsWeb) 'binaryType': binaryType, // coverage:ignore-line
          if (!kIsWeb) 'compression': compression,
          if (!kIsWeb) 'customClient': customClient,
          if (!kIsWeb) 'userAgent': userAgent,
        };

  /// Common options for VM and JS platforms.
  factory SpinifyTransportAdapter.common({
    // Timeout for connection.
    Duration? timeout,
    // Callback called after connection established.
    void Function(WebSocket client)? afterConnect,
    // Additional list of protocols.
    Iterable<String>? protocols,
  }) =>
      SpinifyTransportAdapter._(
        timeout: timeout,
        afterConnect: afterConnect,
        protocols: protocols,
      );

  /// Options for JS (Browser) platform.
  factory SpinifyTransportAdapter.js({
    // Timeout for connection.
    Duration? timeout,
    // Callback called after connection established.
    void Function(WebSocket client)? afterConnect,
    // Additional list of protocols.
    Iterable<String>? protocols,
    // Binary type for JS platform (e.g. 'blob' or 'arraybuffer').
    String? binaryType,
  }) =>
      SpinifyTransportAdapter._(
        timeout: timeout,
        afterConnect: afterConnect,
        protocols: protocols,
        binaryType: binaryType,
      );

  /// Options for VM (Mobile, Desktop, Server, Console) platform.
  factory SpinifyTransportAdapter.vm({
    // Timeout for connection.
    Duration? timeout,
    // Callback called after connection established.
    void Function(WebSocket client)? afterConnect,
    // Additional list of protocols.
    Iterable<String>? protocols,
    // Compression options for VM platform.
    Object? /*CompressionOptions*/ compression,
    // Custom HTTP client for VM platform.
    Object? /*HttpClient*/ customClient,
    // User agent for VM platform.
    String? userAgent,
  }) =>
      SpinifyTransportAdapter._(
        timeout: timeout,
        afterConnect: afterConnect,
        protocols: protocols,
        compression: compression,
        customClient: customClient,
        userAgent: userAgent,
      );

  /// Construct WebSocket adapter for VM or JS platform
  /// depending on the current compile target.
  factory SpinifyTransportAdapter.selector({
    required SpinifyTransportAdapter Function() vm,
    required SpinifyTransportAdapter Function() js,
  }) =>
      kIsWeb ? js() : vm();

  final Map<String, Object?> _options;

  /// Create a Spinify transport
  /// (e.g. WebSocket or gRPC with JSON or Protocol Buffers).
  Future<WebSocket> call({
    required String url, // e.g. 'ws://localhost:8000/connection/websocket'
    Map<String, String>? headers, // e.g. {'Authorization': 'Bearer <token>'}
    Iterable<String>? protocols, // e.g. {'centrifuge-protobuf'}
  }) =>
      $webSocketConnect(
        url: url,
        headers: headers,
        protocols: protocols,
        options: _options,
      );
}
