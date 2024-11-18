import 'dart:async';

import 'subscription_state.dart';

/// Stream of Spinify's [SpinifySubscriptionState] changes.
/// {@category State}
/// {@category Client}
/// {@category Subscription}
extension type SpinifySubscriptionStates<T extends SpinifySubscriptionState>(
    Stream<T> _) implements Stream<T> {
  /// Unsubscribed
  SpinifySubscriptionStates<SpinifySubscriptionState$Unsubscribed>
      unsubscribed() => filter<SpinifySubscriptionState$Unsubscribed>();

  /// Subscribing
  SpinifySubscriptionStates<SpinifySubscriptionState$Subscribing>
      subscribing() => filter<SpinifySubscriptionState$Subscribing>();

  /// Subscribed
  SpinifySubscriptionStates<SpinifySubscriptionState$Subscribed> subscribed() =>
      filter<SpinifySubscriptionState$Subscribed>();

  /// Filtered stream of [SpinifySubscriptionState].
  SpinifySubscriptionStates<S> filter<S extends SpinifySubscriptionState>() =>
      SpinifySubscriptionStates<S>(
          transform<S>(StreamTransformer<T, S>.fromHandlers(
        handleData: (data, sink) => switch (data) {
          S valid => sink.add(valid),
          _ => null,
        },
      )));
}
