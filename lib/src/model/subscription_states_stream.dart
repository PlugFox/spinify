import 'dart:async';

import 'package:centrifuge_dart/src/model/subscription_state.dart';

/// Stream of Centrifuge's [CentrifugeSubscriptionState] changes.
/// {@category Subscription}
/// {@category Entity}
final class CentrifugeSubscriptionStateStream
    extends StreamView<CentrifugeSubscriptionState> {
  /// Stream of Centrifuge's [CentrifugeSubscriptionState] changes.
  CentrifugeSubscriptionStateStream(super.stream);

  /// Unsubscribed
  late final Stream<CentrifugeSubscriptionState$Unsubscribed> unsubscribed =
      whereType<CentrifugeSubscriptionState$Unsubscribed>();

  /// Subscribing
  late final Stream<CentrifugeSubscriptionState$Subscribing> subscribing =
      whereType<CentrifugeSubscriptionState$Subscribing>();

  /// Subscribed
  late final Stream<CentrifugeSubscriptionState$Subscribed> subscribed =
      whereType<CentrifugeSubscriptionState$Subscribed>();

  /// Filtered stream of data of [CentrifugeSubscriptionState].
  Stream<T> whereType<T extends CentrifugeSubscriptionState>() => transform<T>(
          StreamTransformer<CentrifugeSubscriptionState, T>.fromHandlers(
        handleData: (data, sink) => switch (data) {
          T valid => sink.add(valid),
          _ => null,
        },
      )).asBroadcastStream();
}
