import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:spinify/src/model/channel_push.dart';
import 'package:spinify/src/model/exception.dart';
import 'package:spinify/src/subscription/client_subscription_impl.dart';
import 'package:spinify/src/subscription/subscription.dart';
import 'package:spinify/src/subscription/subscription_config.dart';
import 'package:spinify/src/transport/transport_interface.dart';

/// Responsible for managing client-side subscriptions.
/// {@nodoc}
@internal
final class ClientSubscriptionManager {
  /// {@nodoc}
  ClientSubscriptionManager(ISpinifyTransport transport)
      : _transportWeakRef = WeakReference<ISpinifyTransport>(transport);

  /// Spinify client weak reference.
  /// {@nodoc}
  final WeakReference<ISpinifyTransport> _transportWeakRef;

  /// Subscriptions registry (channel -> subscription).
  /// Channel : SpinifyClientSubscription
  /// {@nodoc}
  final Map<String, SpinifyClientSubscriptionImpl> _channelSubscriptions =
      <String, SpinifyClientSubscriptionImpl>{};

  /// Create new client-side subscription.
  /// `newSubscription(channel, config)` allocates a new Subscription
  /// in the registry or throws an exception if the Subscription
  /// is already there. We will discuss common Subscription options below.
  /// {@nodoc}
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
  /// {@nodoc}
  Map<String, SpinifyClientSubscription> get subscriptions =>
      UnmodifiableMapView<String, SpinifyClientSubscription>({
        for (final entry in _channelSubscriptions.entries)
          entry.key: entry.value,
      });

  /// Remove the [SpinifyClientSubscription] from internal registry
  /// and unsubscribe from [SpinifyClientSubscription.channel].
  /// {@nodoc}
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
  /// {@nodoc}
  void subscribeAll() {
    for (final entry in _channelSubscriptions.values) {
      entry.subscribe().ignore();
    }
  }

  /// Disconnect all subscriptions for the specific client
  /// from internal registry.
  /// {@nodoc}
  void unsubscribeAll([
    int code = 0,
    String reason = 'connection closed',
  ]) {
    for (final entry in _channelSubscriptions.values) {
      entry.unsubscribe(code, reason).ignore();
    }
  }

  /// Remove all subscriptions for the specific client from internal registry.
  /// {@nodoc}
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
  /// {@nodoc}
  @internal
  void onPush(SpinifyChannelPush push) =>
      _channelSubscriptions[push.channel]?.onPush(push);

  /// Get subscription to the channel
  /// from internal registry or null if not found.
  ///
  /// You need to call [SpinifyClientSubscription.subscribe]
  /// to start receiving events
  /// {@nodoc}
  SpinifyClientSubscription? operator [](String channel) =>
      _channelSubscriptions[channel];
}
