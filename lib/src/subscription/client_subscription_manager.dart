import 'dart:collection';

import 'package:centrifuge_dart/src/client/centrifuge_interface.dart';
import 'package:centrifuge_dart/src/model/exception.dart';
import 'package:centrifuge_dart/src/model/subscription.dart';
import 'package:centrifuge_dart/src/model/subscription_config.dart';
import 'package:meta/meta.dart';

/// Entry of subscriptions registry.
/// {@nodoc}
typedef ClientSubscriptionEntry = ({
  CentrifugeClientSubscription subscription,
  CentrifugeSubscriptionConfig config,
  WeakReference<ICentrifuge> client
});

/// Responsible for managing subscriptions.
/// {@nodoc}
@internal
final class ClientSubscriptionManager {
  /// {@nodoc}
  factory ClientSubscriptionManager() => _internalSingleton;
  ClientSubscriptionManager._internal();
  static final ClientSubscriptionManager _internalSingleton =
      ClientSubscriptionManager._internal();

  /// Subscriptions registry.
  /// Channel : Subscription entry.
  /// {@nodoc}
  final _subscriptions = <String, ClientSubscriptionEntry>{};

  /// Create new client-side subscription.
  /// `newSubscription(channel, config)` allocates a new Subscription
  /// in the registry or throws an exception if the Subscription
  /// is already there. We will discuss common Subscription options below.
  /// {@nodoc}
  CentrifugeClientSubscription newSubscription(
    String channel,
    CentrifugeSubscriptionConfig? config,
    ICentrifuge client,
  ) {
    if (_subscriptions.containsKey(channel)) {
      throw CentrifugeSubscriptionException(
        subscription: _subscriptions[channel]!.subscription,
        message: 'Subscription to a channel "$channel" already exists '
            'in client\'s internal registry',
      );
    }
    final subscription = CentrifugeClientSubscription(channel: channel);
    _subscriptions[channel] = (
      subscription: subscription,
      config: config ?? const CentrifugeSubscriptionConfig.byDefault(),
      client: WeakReference<ICentrifuge>(client),
    );
    return subscription;
  }

  /// Get map wirth all registered client-side subscriptions.
  /// Returns all registered subscriptions,
  /// so you can iterate over all and do some action if required
  /// (for example, you want to unsubscribe/remove all subscriptions).
  /// {@nodoc}
  Map<String, CentrifugeClientSubscription> get subscriptions =>
      UnmodifiableMapView<String, CentrifugeClientSubscription>({
        for (final entry in _subscriptions.entries)
          entry.key: entry.value.subscription,
      });

  /// Remove the [CentrifugeClientSubscription] from internal registry
  /// and unsubscribe from [CentrifugeClientSubscription.channel].
  /// {@nodoc}
  Future<void> removeSubscription(
    CentrifugeClientSubscription subscription,
  ) async {
    final subFromRegistry = _subscriptions[subscription.channel]?.subscription;
    try {
      // TODO(plugfox): implement
      //subscription.unsubscribe();
      //subscription.close();
      if (!identical(subFromRegistry, subscription)) {
        // If not the same subscription instance - close it too.
        //await subFromRegistry?.unsubscribe();
        //subFromRegistry.close();
      }
    } on CentrifugeException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        CentrifugeSubscriptionException(
          subscription: subscription,
          message: 'Error while unsubscribing',
          error: error,
        ),
        stackTrace,
      );
    }
    _subscriptions.remove(subscription.channel);
  }

  /// Disconnect all subscriptions for the specific client
  /// from internal registry.
  /// {@nodoc}
  Future<void> disconnectAllFor(ICentrifuge client) {
    final toDisconnect = <CentrifugeClientSubscription>[];
    for (final value in _subscriptions.values) {
      if (!identical(value.client.target, client) &&
          value.client.target != null) continue;
      toDisconnect.add(value.subscription);
    }
    for (final subscription in toDisconnect) {
      try {
        // TODO(plugfox): moveToSubscribing if subscribed now
      } on Object {
        /* ignore */
      }
    }
    return Future<void>.value();
  }

  /// Remove all subscriptions for the specific client from internal registry.
  /// {@nodoc}
  Future<void> removeAllFor(ICentrifuge client) async {
    final toRemove = <CentrifugeClientSubscription>[];
    for (final value in _subscriptions.values) {
      if (!identical(value.client.target, client) &&
          value.client.target != null) continue;
      toRemove.add(value.subscription);
    }
    for (final subscription in toRemove) {
      try {
        // TODO(plugfox): moveToSubscribing if subscribed now
        _subscriptions.remove(subscription.channel);
      } on Object {
        /* ignore */
      }
    }
  }

  /// Get subscription to the channel
  /// from internal registry or null if not found.
  ///
  /// You need to call [CentrifugeClientSubscription.subscribe]
  /// to start receiving events
  /// {@nodoc}
  CentrifugeClientSubscription? operator [](String channel) =>
      _subscriptions[channel]?.subscription;
}
