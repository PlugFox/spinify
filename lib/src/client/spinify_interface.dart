// ignore_for_file: one_member_abstracts

import 'dart:async';

import 'package:spinify/src/client/state.dart';
import 'package:spinify/src/client/states_stream.dart';
import 'package:spinify/src/model/history.dart';
import 'package:spinify/src/model/presence.dart';
import 'package:spinify/src/model/presence_stats.dart';
import 'package:spinify/src/model/pushes_stream.dart';
import 'package:spinify/src/model/stream_position.dart';
import 'package:spinify/src/subscription/subscription.dart';
import 'package:spinify/src/subscription/subscription_config.dart';

/// Spinify client interface.
abstract interface class ISpinify
    implements
        ISpinifyStateOwner,
        ISpinifyAsyncMessageSender,
        ISpinifyPublicationSender,
        ISpinifyEventReceiver,
        ISpinifyClientSubscriptionsManager,
        ISpinifyPresenceOwner,
        ISpinifyHistoryOwner,
        ISpinifyRemoteProcedureCall {
  /// Connect to the server.
  /// [url] is a URL of endpoint.
  Future<void> connect(String url);

  /// Ready resolves when client successfully connected.
  /// Throws exceptions if called not in connecting or connected state.
  FutureOr<void> ready();

  /// Disconnect from the server.
  Future<void> disconnect([
    int code = 0,
    String reason = 'Disconnect called',
  ]);

  /// Client if not needed anymore.
  /// Permanent close connection to the server and
  /// free all allocated resources.
  Future<void> close();
}

/// Spinify client state owner interface.
abstract interface class ISpinifyStateOwner {
  /// State of client.
  SpinifyState get state;

  /// Stream of client states.
  abstract final SpinifyStatesStream states;
}

/// Spinify send publication interface.
abstract interface class ISpinifyPublicationSender {
  /// Publish data to specific subscription channel
  Future<void> publish(String channel, List<int> data);
}

/// Spinify send asynchronous message interface.
abstract interface class ISpinifyAsyncMessageSender {
  /// Send asynchronous message to a server. This method makes sense
  /// only when using Centrifuge library for Go on a server side. In Centrifugo
  /// asynchronous message handler does not exist.
  Future<void> send(List<int> data);
}

/// Spinify event receiver interface.
abstract interface class ISpinifyEventReceiver {
  /// Stream of received pushes from Centrifugo server for a channel.
  abstract final SpinifyPushesStream stream;
}

/// Spinify client subscriptions manager interface.
abstract interface class ISpinifyClientSubscriptionsManager {
  /// Create new client-side subscription.
  /// `newSubscription(channel, config)` allocates a new Subscription
  /// in the registry or throws an exception if the Subscription
  /// is already there. We will discuss common Subscription options below.
  SpinifyClientSubscription newSubscription(
    String channel, [
    SpinifySubscriptionConfig? config,
  ]);

  /// Get subscription to the channel
  /// from internal registry or null if not found.
  ///
  /// You need to call [SpinifyClientSubscription.subscribe]
  /// to start receiving events
  /// in the channel.
  SpinifyClientSubscription? getSubscription(String channel);

  /// Remove the [Subscription] from internal registry
  /// and unsubscribe from [SpinifyClientSubscription.channel].
  Future<void> removeSubscription(SpinifyClientSubscription subscription);

  /// Get map wirth all registered client-side subscriptions.
  /// Returns all registered subscriptions,
  /// so you can iterate over all and do some action if required
  /// (for example, you want to unsubscribe/remove all subscriptions).
  Map<String, SpinifyClientSubscription> get subscriptions;
}

/// Spinify presence owner interface.
abstract interface class ISpinifyPresenceOwner {
  /// Fetch presence information inside a channel.
  Future<SpinifyPresence> presence(String channel);

  /// Fetch presence stats information inside a channel.
  Future<SpinifyPresenceStats> presenceStats(String channel);
}

/// Spinify history owner interface.
abstract interface class ISpinifyHistoryOwner {
  /// Fetch publication history inside a channel.
  /// Only for channels where history is enabled.
  Future<SpinifyHistory> history(
    String channel, {
    int? limit,
    SpinifyStreamPosition? since,
    bool? reverse,
  });
}

/// Spinify remote procedure call interface.
abstract interface class ISpinifyRemoteProcedureCall {
  /// Send arbitrary RPC and wait for response.
  Future<List<int>> rpc(String method, List<int> data);
}