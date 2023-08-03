import 'package:centrifuge_dart/centrifuge.dart';
import 'package:centrifuge_dart/src/client/centrifuge_interface.dart';

/// An interface for observing the behavior of Centrifuge instances.
abstract class CentrifugeObserver {
  /// Called whenever a [ICentrifuge] is instantiated.
  void onCreate(ICentrifuge client) {}

  /// Called whenever a [ICentrifuge] client changes its state
  /// to [CentrifugeState$Connecting].
  void onConnected(ICentrifuge client, CentrifugeState$Connected state) {}

  /// Called whenever a [ICentrifuge] client changes its state
  /// to [CentrifugeState$Disconnected].
  void onDisconnected(ICentrifuge client, CentrifugeState$Disconnected state) {}

  /// Called whenever an error is thrown in any Centrifuge client.
  void onError(CentrifugeException error, StackTrace stackTrace) {}

  /// Called whenever a [ICentrifuge] is closed.
  void onClose(ICentrifuge client) {}
}
