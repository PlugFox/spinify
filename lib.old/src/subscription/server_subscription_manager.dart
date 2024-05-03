import 'dart:collection';

import 'package:meta/meta.dart';

import '../model/channel_push.dart';
import '../model/subscribe.dart';
import '../model/unsubscribe.dart';
import '../transport/transport_interface.dart';
import 'server_subscription_impl.dart';
import 'subscription.dart';
import 'subscription_state.dart';

/// Responsible for managing client-side subscriptions.
@internal
final class ServerSubscriptionManager {
  ServerSubscriptionManager(ISpinifyTransport transport)
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
  final Map<String, SpinifyServerSubscriptionImpl> _channelSubscriptions =
      <String, SpinifyServerSubscriptionImpl>{};

  /// Get map wirth all registered client-side subscriptions.
  /// Returns all registered subscriptions,
  /// so you can iterate over all and do some action if required
  /// (for example, you want to unsubscribe/remove all subscriptions).
  Map<String, SpinifyServerSubscription> get subscriptions =>
      UnmodifiableMapView<String, SpinifyServerSubscription>({
        for (final entry in _channelSubscriptions.entries)
          entry.key: entry.value,
      });

  /// Called on [SpinifySubscribe] push from server.
  void subscribe(SpinifySubscribe subscribe) {}

  /// Called on [SpinifyUnsubscribe] push from server.
  void unsubscribe(SpinifyUnsubscribe subscribe) {}

  /// Called when client finished connection handshake with server.
  /// Add non existing subscriptions to registry and mark all connected.
  /// Remove subscriptions which are not in [subs] argument.
  void upsert(List<SpinifySubscribe> subs) {
    final currentChannels = _channelSubscriptions.keys.toSet();
    // Remove subscriptions which are not in subs argument.
    for (final channel in currentChannels) {
      if (subs.any((e) => e.channel == channel)) continue;
      _channelSubscriptions.remove(channel)?.close();
    }
    // Add non existing subscriptions to registry and mark all connected.
    for (final sub in subs) {
      (_channelSubscriptions[sub.channel] ??= SpinifyServerSubscriptionImpl(
        channel: sub.channel,
        transportWeakRef: _transportWeakRef,
      ))
          .onPush(sub);
    }
  }

  /// Called when subscribed to a server-side channel upon Client moving to
  /// connected state or during connection lifetime if server sends Subscribe
  /// push message.
  void setSubscribedAll() {
    for (final entry in _channelSubscriptions.values) {
      if (entry.state.isSubscribed) continue;
    }
  }

  /// Called when existing connection lost (Client reconnects) or Client
  /// explicitly disconnected. Client continue keeping server-side subscription
  /// registry with stream position information where applicable.
  void setSubscribingAll() {
    for (final entry in _channelSubscriptions.values) {
      if (entry.state.isSubscribing) continue;
      entry.setSubscribing();
    }
  }

  /// Called when server sent unsubscribe push or server-side subscription
  /// previously existed in SDK registry disappeared upon Client reconnect.
  void setUnsubscribedAll([int code = 0, String reason = 'unsubscribed']) {
    for (final entry in _channelSubscriptions.values) {
      if (entry.state.isUnsubscribed) continue;
      entry.setUnsubscribed(code, reason);
    }
  }

  /// Close all subscriptions.
  void close([
    int code = 0,
    String reason = 'client closed',
  ]) {
    for (final entry in _channelSubscriptions.values) {
      entry.close(code, reason).ignore();
    }
    _channelSubscriptions.clear();
  }

  /// Handle push event from server for the specific channel.
  @internal
  void onPush(SpinifyChannelPush push) =>
      _channelSubscriptions[push.channel]?.onPush(push);

  /// Get subscription to the channel
  /// from internal registry or null if not found.
  ///
  /// You need to call [SpinifyClientSubscription.subscribe]
  /// to start receiving events
  SpinifyServerSubscription? operator [](String channel) =>
      _channelSubscriptions[channel];
}
