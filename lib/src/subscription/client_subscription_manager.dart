import 'dart:collection';

import 'package:centrifuge_dart/src/model/channel_push.dart';
import 'package:centrifuge_dart/src/model/exception.dart';
import 'package:centrifuge_dart/src/subscription/client_subscription_impl.dart';
import 'package:centrifuge_dart/src/subscription/subscription.dart';
import 'package:centrifuge_dart/src/subscription/subscription_config.dart';
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
      await subFromRegistry?.unsubscribe();
      if (!identical(subFromRegistry, subscription)) {
        // If not the same subscription instance - unsubscribe it too.
        await subscription.unsubscribe();
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
    } finally {
      subFromRegistry?.close().ignore();
      _channelSubscriptions.remove(subscription.channel);
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
  void onPush(CentrifugeChannelPush push) =>
      _channelSubscriptions[push.channel]?.onPush(push);

  /// Get subscription to the channel
  /// from internal registry or null if not found.
  ///
  /// You need to call [CentrifugeClientSubscription.subscribe]
  /// to start receiving events
  /// {@nodoc}
  CentrifugeClientSubscription? operator [](String channel) =>
      _channelSubscriptions[channel];
}
