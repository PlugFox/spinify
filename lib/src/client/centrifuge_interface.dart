// ignore_for_file: one_member_abstracts

import 'dart:async';

import 'package:centrifuge_dart/centrifuge.dart';
import 'package:centrifuge_dart/src/model/presence.dart';
import 'package:centrifuge_dart/src/model/presence_stats.dart';
import 'package:centrifuge_dart/src/model/pushes_stream.dart';

/// Centrifuge client interface.
abstract interface class ICentrifuge
    implements
        ICentrifugeStateOwner,
        ICentrifugeAsyncMessageSender,
        ICentrifugePublicationSender,
        ICentrifugeEventReceiver,
        ICentrifugeClientSubscriptionsManager,
        ICentrifugePresenceOwner {
  /// Stream of errors.
  abstract final Stream<
      ({CentrifugeException exception, StackTrace stackTrace})> errors;

  /// Connect to the server.
  /// [url] is a URL of endpoint.
  Future<void> connect(String url);

  /// Ready resolves when client successfully connected.
  /// Throws exceptions if called not in connecting or connected state.
  FutureOr<void> ready();

  /// Disconnect from the server.
  Future<void> disconnect();

  /// Client if not needed anymore.
  /// Permanent close connection to the server and
  /// free all allocated resources.
  Future<void> close();

  /// Send arbitrary RPC and wait for response.
  /* Future<void> rpc(String method, data); */

  /// Publish data to the channel.
  /* Future<PublishResult> publish(String channel, List<int> data); */

  /// Send History command.
  /* Future<HistoryResult> history(String channel,
      {int limit = 0, StreamPosition? since, bool reverse = false}); */
}

/// Centrifuge client state owner interface.
abstract interface class ICentrifugeStateOwner {
  /// State of client.
  CentrifugeState get state;

  /// Stream of client states.
  abstract final CentrifugeStatesStream states;
}

/// Centrifuge send publication interface.
abstract interface class ICentrifugePublicationSender {
  /// Publish data to specific subscription channel
  Future<void> publish(String channel, List<int> data);
}

/// Centrifuge send asynchronous message interface.
abstract interface class ICentrifugeAsyncMessageSender {
  /// Send asynchronous message to a server. This method makes sense
  /// only when using Centrifuge library for Go on a server side. In Centrifuge
  /// asynchronous message handler does not exist.
  Future<void> send(List<int> data);
}

/// Centrifuge event receiver interface.
abstract interface class ICentrifugeEventReceiver {
  /// Stream of received pushes from Centrifugo server for a channel.
  abstract final CentrifugePushesStream stream;
}

/// Centrifuge client subscriptions manager interface.
abstract interface class ICentrifugeClientSubscriptionsManager {
  /// Create new client-side subscription.
  /// `newSubscription(channel, config)` allocates a new Subscription
  /// in the registry or throws an exception if the Subscription
  /// is already there. We will discuss common Subscription options below.
  CentrifugeClientSubscription newSubscription(
    String channel, [
    CentrifugeSubscriptionConfig? config,
  ]);

  /// Get subscription to the channel
  /// from internal registry or null if not found.
  ///
  /// You need to call [CentrifugeClientSubscription.subscribe]
  /// to start receiving events
  /// in the channel.
  CentrifugeClientSubscription? getSubscription(String channel);

  /// Remove the [Subscription] from internal registry
  /// and unsubscribe from [CentrifugeClientSubscription.channel].
  Future<void> removeSubscription(CentrifugeClientSubscription subscription);

  /// Get map wirth all registered client-side subscriptions.
  /// Returns all registered subscriptions,
  /// so you can iterate over all and do some action if required
  /// (for example, you want to unsubscribe/remove all subscriptions).
  Map<String, CentrifugeClientSubscription> get subscriptions;
}

/// Centrifuge presence owner interface.
abstract interface class ICentrifugePresenceOwner {
  /// Fetch presence information inside a channel.
  Future<CentrifugePresence> presence(String channel);

  /// Fetch presence stats information inside a channel.
  Future<CentrifugePresenceStats> presenceStats(String channel);
}
