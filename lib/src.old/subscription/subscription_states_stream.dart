import 'dart:async';

import 'package:meta/meta.dart';
import 'package:spinify/src.old/subscription/subscription_state.dart';

/// Stream of Spinify's [SpinifySubscriptionState] changes.
/// {@category Subscription}
/// {@category Entity}
@immutable
final class SpinifySubscriptionStateStream
    extends StreamView<SpinifySubscriptionState> {
  /// Stream of Spinify's [SpinifySubscriptionState] changes.
  SpinifySubscriptionStateStream(super.stream);

  /// Unsubscribed
  late final Stream<SpinifySubscriptionState$Unsubscribed> unsubscribed =
      whereType<SpinifySubscriptionState$Unsubscribed>();

  /// Subscribing
  late final Stream<SpinifySubscriptionState$Subscribing> subscribing =
      whereType<SpinifySubscriptionState$Subscribing>();

  /// Subscribed
  late final Stream<SpinifySubscriptionState$Subscribed> subscribed =
      whereType<SpinifySubscriptionState$Subscribed>();

  /// Filtered stream of data of [SpinifySubscriptionState].
  Stream<T> whereType<T extends SpinifySubscriptionState>() =>
      transform<T>(StreamTransformer<SpinifySubscriptionState, T>.fromHandlers(
        handleData: (data, sink) => switch (data) {
          T valid => sink.add(valid),
          _ => null,
        },
      )).asBroadcastStream();

  @override
  String toString() => 'SpinifySubscriptionStateStream{}';
}
