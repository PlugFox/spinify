import 'dart:collection';

import 'package:centrifuge_dart/src/model/channel_push.dart';
import 'package:centrifuge_dart/src/model/subscribe.dart';
import 'package:centrifuge_dart/src/model/unsubscribe.dart';
import 'package:centrifuge_dart/src/subscription/server_subscription_impl.dart';
import 'package:centrifuge_dart/src/subscription/subscription.dart';
import 'package:centrifuge_dart/src/transport/transport_interface.dart';
import 'package:meta/meta.dart';

/// Responsible for managing client-side subscriptions.
/// {@nodoc}
@internal
final class ServerSubscriptionManager {
  /// {@nodoc}
  ServerSubscriptionManager(ICentrifugeTransport transport)
      : _transportWeakRef = WeakReference<ICentrifugeTransport>(transport);

  /// Centrifuge client weak reference.
  /// {@nodoc}
  final WeakReference<ICentrifugeTransport> _transportWeakRef;

  /// Subscriptions registry (channel -> subscription).
  /// Channel : CentrifugeClientSubscription
  /// {@nodoc}
  final Map<String, CentrifugeServerSubscriptionImpl> _channelSubscriptions =
      <String, CentrifugeServerSubscriptionImpl>{};

  /// Get map wirth all registered client-side subscriptions.
  /// Returns all registered subscriptions,
  /// so you can iterate over all and do some action if required
  /// (for example, you want to unsubscribe/remove all subscriptions).
  /// {@nodoc}
  Map<String, CentrifugeServerSubscription> get subscriptions =>
      UnmodifiableMapView<String, CentrifugeServerSubscription>({
        for (final entry in _channelSubscriptions.entries)
          entry.key: entry.value,
      });

  /// Called on [CentrifugeSubscribe] push from server.
  void subscribe(CentrifugeSubscribe subscribe) {}

  /// Called on [CentrifugeUnsubscribe] push from server.
  void unsubscribe(CentrifugeUnsubscribe subscribe) {}

  /// Called when client finished connection handshake with server.
  /// Add non existing subscriptions to registry and mark all connected.
  /// Remove subscriptions which are not in [subs] argument.
  void upsert(List<CentrifugeSubscribe> subs) {
    final currentChannels = _channelSubscriptions.keys.toSet();
    // Remove subscriptions which are not in subs argument.
    for (final channel in currentChannels) {
      if (subs.any((e) => e.channel == channel)) continue;
      _channelSubscriptions.remove(channel)?.close();
    }
    // Add non existing subscriptions to registry and mark all connected.
    for (final sub in subs) {
      (_channelSubscriptions[sub.channel] ??= CentrifugeServerSubscriptionImpl(
        channel: sub.channel,
        transportWeakRef: _transportWeakRef,
      ))
          .onPush(sub);
    }
  }

  /// Called when subscribed to a server-side channel upon Client moving to
  /// connected state or during connection lifetime if server sends Subscribe
  /// push message.
  /// {@nodoc}
  void setSubscribedAll() {
    for (final entry in _channelSubscriptions.values) {
      if (entry.state.isSubscribed) continue;
    }
  }

  /// Called when existing connection lost (Client reconnects) or Client
  /// explicitly disconnected. Client continue keeping server-side subscription
  /// registry with stream position information where applicable.
  /// {@nodoc}
  void setSubscribingAll() {
    for (final entry in _channelSubscriptions.values) {
      if (entry.state.isSubscribing) continue;
    }
  }

  /// Called when server sent unsubscribe push or server-side subscription
  /// previously existed in SDK registry disappeared upon Client reconnect.
  /// {@nodoc}
  void setUnsubscribedAll() {
    for (final entry in _channelSubscriptions.values) {
      if (entry.state.isUnsubscribed) continue;
    }
  }

  /// Close all subscriptions.
  /// {@nodoc}
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
  CentrifugeServerSubscription? operator [](String channel) =>
      _channelSubscriptions[channel];
}
