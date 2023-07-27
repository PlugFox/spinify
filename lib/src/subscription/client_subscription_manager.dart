import 'dart:collection';

import 'package:centrifuge_dart/src/model/exception.dart';
import 'package:centrifuge_dart/src/model/subscription.dart';
import 'package:centrifuge_dart/src/model/subscription_config.dart';
import 'package:centrifuge_dart/src/subscription/client_subscription_impl.dart';
import 'package:centrifuge_dart/src/transport/transport_interface.dart';
import 'package:meta/meta.dart';

/// Responsible for managing client-side subscriptions.
/// {@nodoc}
@internal
final class ClientSubscriptionManager {
  /// {@nodoc}
  ClientSubscriptionManager(ICentrifugeTransport transport)
      : _transportWeakRef = WeakReference<ICentrifugeTransport>(transport);

  /// Centrifuge client weak reference.
  /// {@nodoc}
  final WeakReference<ICentrifugeTransport> _transportWeakRef;

  /// Subscriptions registry (channel -> subscription).
  /// Channel : CentrifugeClientSubscription
  /// {@nodoc}
  final Map<String, CentrifugeClientSubscriptionImpl> _channelSubscriptions =
      <String, CentrifugeClientSubscriptionImpl>{};

  /// Create new client-side subscription.
  /// `newSubscription(channel, config)` allocates a new Subscription
  /// in the registry or throws an exception if the Subscription
  /// is already there. We will discuss common Subscription options below.
  /// {@nodoc}
  CentrifugeClientSubscription newSubscription(
    String channel,
    CentrifugeSubscriptionConfig? config,
  ) {
    if (_channelSubscriptions.containsKey(channel)) {
      throw CentrifugeSubscriptionException(
        channel: channel,
        message: 'Subscription to a channel "$channel" already exists '
            'in client\'s internal registry',
      );
    }
    return _channelSubscriptions[channel] = CentrifugeClientSubscriptionImpl(
      channel: channel,
      config: config ?? const CentrifugeSubscriptionConfig.byDefault(),
      transportWeakRef: _transportWeakRef,
    );
  }

  /// Get map wirth all registered client-side subscriptions.
  /// Returns all registered subscriptions,
  /// so you can iterate over all and do some action if required
  /// (for example, you want to unsubscribe/remove all subscriptions).
  /// {@nodoc}
  Map<String, CentrifugeClientSubscription> get subscriptions =>
      UnmodifiableMapView<String, CentrifugeClientSubscription>({
        for (final entry in _channelSubscriptions.entries)
          entry.key: entry.value,
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
          channel: subscription.channel,
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
  void disconnectAll() {
    for (final entry in _channelSubscriptions.values) {
      try {
        // TODO(plugfox): moveToSubscribing if subscribed now
      } on Object {
        /* ignore */
      }
    }
  }

  /// Remove all subscriptions for the specific client from internal registry.
  /// {@nodoc}
  void removeAll() {
    for (final entry in _channelSubscriptions.values) {
      try {
        // TODO(plugfox): moveToSubscribing if subscribed now
      } on Object {
        /* ignore */
      }
    }
    _channelSubscriptions.clear();
  }

  /// Get subscription to the channel
  /// from internal registry or null if not found.
  ///
  /// You need to call [CentrifugeClientSubscription.subscribe]
  /// to start receiving events
  /// {@nodoc}
  CentrifugeClientSubscription? operator [](String channel) =>
      _channelSubscriptions[channel];
}
