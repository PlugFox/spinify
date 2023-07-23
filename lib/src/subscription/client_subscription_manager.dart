import 'dart:collection';

import 'package:centrifuge_dart/src/client/centrifuge_interface.dart';
import 'package:centrifuge_dart/src/model/exception.dart';
import 'package:centrifuge_dart/src/model/subscription.dart';
import 'package:centrifuge_dart/src/model/subscription_config.dart';
import 'package:centrifuge_dart/src/subscription/client_subscription_controller.dart';
import 'package:meta/meta.dart';

/// Entry of channel subscriptions registry.
/// {@nodoc}
typedef ClientSubscriptionRegistryEntry = ({
  CentrifugeClientSubscription subscription,
  ClientSubscriptionController controller
});

/// Responsible for managing client-side subscriptions.
/// {@nodoc}
@internal
final class ClientSubscriptionManager {
  /// {@nodoc}
  factory ClientSubscriptionManager() => _internalSingleton;
  ClientSubscriptionManager._internal();
  static final ClientSubscriptionManager _internalSingleton =
      ClientSubscriptionManager._internal();

  /// Subscriptions registry (channel -> subscription).
  /// Channel : CentrifugeClientSubscription
  /// {@nodoc}
  final Map<String, ClientSubscriptionRegistryEntry> _channelSubscriptions =
      <String, ClientSubscriptionRegistryEntry>{};

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
    if (_channelSubscriptions.containsKey(channel)) {
      throw CentrifugeSubscriptionException(
        subscription: _channelSubscriptions[channel]!.subscription,
        message: 'Subscription to a channel "$channel" already exists '
            'in client\'s internal registry',
      );
    }
    final controller = ClientSubscriptionController(
      config: config ?? const CentrifugeSubscriptionConfig.byDefault(),
      client: WeakReference<ICentrifuge>(client),
    );
    final subscription = CentrifugeClientSubscriptionImpl(
      channel: channel,
      controller: controller,
    );
    _channelSubscriptions[channel] =
        (subscription: subscription, controller: controller);
    return subscription;
  }

  /// Get map wirth all registered client-side subscriptions.
  /// Returns all registered subscriptions,
  /// so you can iterate over all and do some action if required
  /// (for example, you want to unsubscribe/remove all subscriptions).
  /// {@nodoc}
  Map<String, CentrifugeClientSubscription> get subscriptions =>
      UnmodifiableMapView<String, CentrifugeClientSubscription>({
        for (final entry in _channelSubscriptions.entries)
          entry.key: entry.value.subscription,
      });

  /// Remove the [CentrifugeClientSubscription] from internal registry
  /// and unsubscribe from [CentrifugeClientSubscription.channel].
  /// {@nodoc}
  Future<void> removeSubscription(
    CentrifugeClientSubscription subscription,
  ) async {
    final subFromRegistry = _channelSubscriptions[subscription.channel];
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
    _channelSubscriptions.remove(subscription.channel);
  }

  /// Disconnect all subscriptions for the specific client
  /// from internal registry.
  /// {@nodoc}
  Future<void> disconnectAllFor(ICentrifuge client) {
    final toDisconnect = <CentrifugeClientSubscription>[];
    for (final value in _channelSubscriptions.values) {
      if (!identical(value.controller.client.target, client) &&
          value.controller.client.target != null) continue;
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
    for (final value in _channelSubscriptions.values) {
      if (!identical(value.controller.client.target, client) &&
          value.controller.client.target != null) continue;
      toRemove.add(value.subscription);
    }
    for (final subscription in toRemove) {
      try {
        // TODO(plugfox): moveToSubscribing if subscribed now
        _channelSubscriptions.remove(subscription.channel);
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
      _channelSubscriptions[channel]?.subscription;
}
