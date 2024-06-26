import 'dart:collection';

import '../model/channel_push.dart';
import '../model/exception.dart';
import '../transport/transport_interface.dart';
import 'client_subscription_impl.dart';
import 'subscription.dart';
import 'subscription_config.dart';
import 'subscription_state.dart';

/// Responsible for managing client-side subscriptions.
final class ClientSubscriptionManager {
  /// Responsible for managing client-side subscriptions.
  ClientSubscriptionManager(ISpinifyTransport transport)
      : _transportWeakRef = WeakReference<ISpinifyTransport>(transport);

  /// Spinify client weak reference.
  final WeakReference<ISpinifyTransport> _transportWeakRef;

  /// Subscriptions count.
  ({int total, int unsubscribed, int subscribing, int subscribed}) get count {
    var total = 0, unsubscribed = 0, subscribing = 0, subscribed = 0;
    for (final entry in _channelSubscriptions.values) {
      total++;
      switch (entry.state) {
        case SpinifySubscriptionState$Unsubscribed _:
          unsubscribed++;
        case SpinifySubscriptionState$Subscribing _:
          subscribing++;
        case SpinifySubscriptionState$Subscribed _:
          subscribed++;
      }
    }
    return (
      total: total,
      unsubscribed: unsubscribed,
      subscribing: subscribing,
      subscribed: subscribed,
    );
  }

  /// Subscriptions registry (channel -> subscription).
  /// Channel : SpinifyClientSubscription
  final Map<String, SpinifyClientSubscriptionImpl> _channelSubscriptions =
      <String, SpinifyClientSubscriptionImpl>{};

  /// Create new client-side subscription.
  /// `newSubscription(channel, config)` allocates a new Subscription
  /// in the registry or throws an exception if the Subscription
  /// is already there. We will discuss common Subscription options below.
  SpinifyClientSubscription newSubscription(
    String channel,
    SpinifySubscriptionConfig? config,
  ) {
    if (_channelSubscriptions.containsKey(channel)) {
      throw SpinifySubscriptionException(
        channel: channel,
        message: 'Subscription to a channel "$channel" already exists '
            'in client\'s internal registry',
      );
    }
    return _channelSubscriptions[channel] = SpinifyClientSubscriptionImpl(
      channel: channel,
      config: config ?? const SpinifySubscriptionConfig.byDefault(),
      transportWeakRef: _transportWeakRef,
    );
  }

  /// Get map wirth all registered client-side subscriptions.
  /// Returns all registered subscriptions,
  /// so you can iterate over all and do some action if required
  /// (for example, you want to unsubscribe/remove all subscriptions).
  Map<String, SpinifyClientSubscription> get subscriptions =>
      UnmodifiableMapView<String, SpinifyClientSubscription>({
        for (final entry in _channelSubscriptions.entries)
          entry.key: entry.value,
      });

  /// Remove the [SpinifyClientSubscription] from internal registry
  /// and unsubscribe from [SpinifyClientSubscription.channel].
  Future<void> removeSubscription(
    SpinifyClientSubscription subscription,
  ) async {
    final subFromRegistry = _channelSubscriptions[subscription.channel];
    try {
      await subFromRegistry?.unsubscribe();
      if (!identical(subFromRegistry, subscription)) {
        // If not the same subscription instance - unsubscribe it too.
        await subscription.unsubscribe();
      }
    } on SpinifyException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        SpinifySubscriptionException(
          channel: subscription.channel,
          message: 'Error while unsubscribing',
          error: error,
        ),
        stackTrace,
      );
    } finally {
      _channelSubscriptions.remove(subscription.channel)?.close().ignore();
    }
  }

  /// Establish all subscriptions for the specific client.
  void subscribeAll() {
    for (final entry in _channelSubscriptions.values) {
      entry.subscribe().ignore();
    }
  }

  /// Disconnect all subscriptions for the specific client
  /// from internal registry.
  void unsubscribeAll([
    int code = 0,
    String reason = 'connection closed',
  ]) {
    for (final entry in _channelSubscriptions.values) {
      entry.unsubscribe(code, reason).ignore();
    }
  }

  /// Remove all subscriptions for the specific client from internal registry.
  void close([
    int code = 0,
    String reason = 'client closed',
  ]) {
    for (final entry in _channelSubscriptions.values) {
      entry.unsubscribe(code, reason).whenComplete(entry.close).ignore();
    }
    _channelSubscriptions.clear();
  }

  /// Handle push event from server for the specific channel.
  void onPush(SpinifyChannelPush push) =>
      _channelSubscriptions[push.channel]?.onPush(push);

  /// Get subscription to the channel
  /// from internal registry or null if not found.
  ///
  /// You need to call [SpinifyClientSubscription.subscribe]
  /// to start receiving events
  SpinifyClientSubscription? operator [](String channel) =>
      _channelSubscriptions[channel];
}
