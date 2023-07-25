import 'dart:async';

import 'package:centrifuge_dart/centrifuge.dart';
import 'package:centrifuge_dart/src/model/subscription_states_stream.dart';
import 'package:centrifuge_dart/src/transport/transport_interface.dart';
import 'package:meta/meta.dart';

/// Constroller responsible for managing subscription.
/// {@nodoc}
@internal
final class CentrifugeClientSubscriptionImpl
    implements CentrifugeClientSubscription {
  /// {@nodoc}
  CentrifugeClientSubscriptionImpl({
    required this.channel,
    required this.config,
    required this.transport,
  });

  @override
  final String channel;

  /// Subscription config.
  /// {@nodoc}
  final CentrifugeSubscriptionConfig config;

  /// Weak reference to client.
  /// {@nodoc}
  final WeakReference<ICentrifugeTransport> transport;

  /// Subscription has 3 states:
  /// - `unsubscribed`
  /// - `subscribing`
  /// - `subscribed`
  /// {@nodoc}
  @override
  CentrifugeSubscriptionState get state => _state;
  CentrifugeSubscriptionState _state =
      CentrifugeSubscriptionState.unsubscribed();

  /// Stream of subscription states.
  /// {@nodoc}
  @override
  late final CentrifugeSubscriptionStateStream states =
      CentrifugeSubscriptionStateStream(_stateController.stream);

  /// States controller.
  /// {@nodoc}
  final StreamController<CentrifugeSubscriptionState> _stateController =
      StreamController<CentrifugeSubscriptionState>.broadcast();

  /// Set new state.
  /// {@nodoc}
  void _setState(CentrifugeSubscriptionState state) {
    if (_state == state) return;
    _stateController.add(_state = state);
  }

  /// Stream of publications.
  /// {@nodoc}
  @override
  Stream<CentrifugePublication> get publications =>
      _publicationController.stream;

  /// {@nodoc}
  final StreamController<CentrifugePublication> _publicationController =
      StreamController<CentrifugePublication>.broadcast();

  /// Await for subscription to be ready.
  /// {@nodoc}
  @override
  FutureOr<void> ready() async {
    switch (state) {
      case CentrifugeSubscriptionState$Unsubscribed _:
        throw CentrifugeSubscriptionException(
          message: 'Subscription is not subscribed',
          subscription: this,
        );
      case CentrifugeSubscriptionState$Subscribed _:
        return;
      case CentrifugeSubscriptionState$Subscribing _:
        await states.subscribed.first.timeout(config.timeout).onError<Object>(
              (error, stackTrace) => throw CentrifugeSubscriptionException(
                message: 'Subscription is not subscribed',
                subscription: this,
                error: error,
              ),
            );
    }
  }

  /// Start subscribing to a channel
  /// {@nodoc}
  @override
  Future<void> subscribe() async {
    if (state is CentrifugeSubscriptionState$Subscribed) return;
    if (state is CentrifugeSubscriptionState$Subscribing) return await ready();
    _setState(CentrifugeSubscriptionState$Subscribing());
    // TODO(plugfox): implement
  }

  /// Unsubscribe from a channel
  /// {@nodoc}
  @override
  Future<void> unsubscribe() async {
    // TODO(plugfox): implement
  }

  /* publish(data) - publish data to Subscription channel
  history(options) - request Subscription channel history
  presence() - request Subscription channel online presence information
  presenceStats() - request Subscription channel online presence stats information (number of client connections and unique users in a channel).
 */

  /// {@nodoc}
  @internal
  void close() {
    _publicationController.close().ignore();
  }
}
