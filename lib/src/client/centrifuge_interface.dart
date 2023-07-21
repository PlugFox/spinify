import 'package:centrifuge_dart/src/model/state.dart';

/// Centrifuge client interface.
abstract interface class ICentrifuge {
  /// State of client.
  CentrifugeState get state;

  /// Stream of client states.
  abstract final Stream<CentrifugeState> states;

  /* abstract final Stream<Object> publications; */

  /// Connect to the server.
  /// [url] is a URL of endpoint.
  Future<void> connect(String url);

  /// Send asynchronous message to a server. This method makes sense
  /// only when using Centrifuge library for Go on a server side. In Centrifugo
  /// asynchronous message handler does not exist.
  /* Future<void> send(List<int> data); */

  /// Publish data to the channel.
  /* Future<PublishResult> publish(String channel, List<int> data); */

  /// Disconnect from the server.
  Future<void> disconnect();

  /// Client if not needed anymore.
  /// Permanent close connection to the server and
  /// free all allocated resources.
  Future<void> close();

  /// Send arbitrary RPC and wait for response.
  /* Future<void> rpc(String method, data); */
}
