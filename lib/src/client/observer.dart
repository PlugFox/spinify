import 'package:spinify/src/client/centrifuge_interface.dart';
import 'package:spinify/src/client/state.dart';
import 'package:spinify/src/model/event.dart';
import 'package:spinify/src/model/exception.dart';
import 'package:spinify/src/subscription/subscription.dart';
import 'package:spinify/src/subscription/subscription_state.dart';

/// An interface for observing the behavior of Centrifuge instances.
/// {@category Client}
/// {@subCategory Observer}
abstract class SpinifyObserver {
  /// Called whenever a [ISpinify] is instantiated.
  void onCreate(ISpinify client) {}

  /// Called whenever a [ISpinify] client changes its state
  /// to [CentrifugeState$Connecting].
  void onConnected(ISpinify client, CentrifugeState$Connected state) {}

  /// Called whenever a [ISpinify] client receives a [CentrifugeEvent].
  void onEvent(ISpinify client, CentrifugeEvent event) {}

  /// Called whenever a [ISpinify] client changes its state
  /// from [prev] to [next].
  void onStateChanged(
      ISpinify client, CentrifugeState prev, CentrifugeState next) {}

  /// Called whenever a [ISpinifySubscription] changes its state
  /// from [prev] to [next].
  /// Works both for client-side and server-side subscriptions.
  void onSubscriptionChanged(ISpinifySubscription subscription,
      CentrifugeSubscriptionState prev, CentrifugeSubscriptionState next) {}

  /// Called whenever a [ISpinify] client changes its state
  /// to [CentrifugeState$Disconnected].
  void onDisconnected(ISpinify client, CentrifugeState$Disconnected state) {}

  /// Called whenever an error is thrown in any Centrifuge client.
  void onError(CentrifugeException error, StackTrace stackTrace) {}

  /// Called whenever a [ISpinify] is closed.
  void onClose(ISpinify client) {}
}
