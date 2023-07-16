import 'package:centrifuge_dart/src/model/state.dart';

/// Centrifuge client interface.
abstract interface class ICentrifuge {
  /// State of client.
  CentrifugeState get state;

  /// Stream of client states.
  abstract final Stream<CentrifugeState> states;

  /// Connect to the server.
  /// [url] is a URL of endpoint.
  Future<void> connect(String url);

  /// Disconnect from the server.
  Future<void> disconnect();

  /// Client if not needed anymore.
  /// Permanent close connection to the server and
  /// free all allocated resources.
  Future<void> close();

  /// Send asynchronous message to the server.
  /* Future<void> send( data); */

  /// Send arbitrary RPC and wait for response.
  /* Future<void> rpc(String method, data); */
}
