import 'package:spinify/src.old/client/spinify_interface.dart';
import 'package:spinify/src.old/client/state.dart';
import 'package:spinify/src.old/model/event.dart';
import 'package:spinify/src.old/model/exception.dart';
import 'package:spinify/src.old/subscription/subscription.dart';
import 'package:spinify/src.old/subscription/subscription_state.dart';

/// An interface for observing the behavior of Spinify instances.
/// {@category Client}
/// {@subCategory Observer}
abstract class SpinifyObserver {
  /// Called whenever a [ISpinify] is instantiated.
  void onCreate(ISpinify client) {}

  /// Called whenever a [ISpinify] client changes its state
  /// to [SpinifyState$Connecting].
  void onConnected(ISpinify client, SpinifyState$Connected state) {}

  /// Called whenever a [ISpinify] client receives a [SpinifyEvent].
  void onEvent(ISpinify client, SpinifyEvent event) {}

  /// Called whenever a [ISpinify] client changes its state
  /// from [prev] to [next].
  void onStateChanged(ISpinify client, SpinifyState prev, SpinifyState next) {}

  /// Called whenever a [SpinifySubscription] changes its state
  /// from [prev] to [next].
  /// Works both for client-side and server-side subscriptions.
  void onSubscriptionChanged(SpinifySubscription subscription,
      SpinifySubscriptionState prev, SpinifySubscriptionState next) {}

  /// Called whenever a [ISpinify] client changes its state
  /// to [SpinifyState$Disconnected].
  void onDisconnected(ISpinify client, SpinifyState$Disconnected state) {}

  /// Called whenever an error is thrown in any Spinify client.
  void onError(SpinifyException error, StackTrace stackTrace) {}

  /// Called whenever a [ISpinify] is closed.
  void onClose(ISpinify client) {}
}
