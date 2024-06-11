// ignore_for_file: one_member_abstracts

import 'dart:async';

import 'model/channel_event.dart';
import 'model/channel_events.dart';
import 'model/config.dart';
import 'model/history.dart';
import 'model/metric.dart';
import 'model/presence_stats.dart';
import 'model/state.dart';
import 'model/states_stream.dart';
import 'model/stream_position.dart';
import 'model/subscription_config.dart';
import 'subscription_interface.dart';

/// Spinify client interface.
abstract interface class ISpinify
    implements
        ISpinifyStateOwner,
        ISpinifyAsyncMessageSender,
        ISpinifyPublicationSender,
        ISpinifyEventReceiver,
        ISpinifySubscriptionsManager,
        ISpinifyPresenceOwner,
        ISpinifyHistoryOwner,
        ISpinifyRemoteProcedureCall,
        ISpinifyMetricsOwner {
  /// Spinify configuration.
  abstract final SpinifyConfig config;

  /// True if client is closed.
  bool get isClosed;

  /// Connect to the server.
  /// [url] is a URL of endpoint.
  Future<void> connect(String url);

  /// Ready resolves when client successfully connected.
  /// Throws exceptions if called not in connecting or connected state.
  Future<void> ready();

  /// Disconnect from the server.
  Future<void> disconnect();

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
  abstract final SpinifyChannelEvents<SpinifyChannelEvent> stream;
}

/// Spinify client subscriptions manager interface.
abstract interface class ISpinifySubscriptionsManager {
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

  /// Remove the [SpinifySubscription] from internal registry
  /// and unsubscribe from [SpinifyClientSubscription.channel].
  Future<void> removeSubscription(SpinifyClientSubscription subscription);

  /// Get map wirth all registered client-side & server-side subscriptions.
  /// Returns all registered subscriptions,
  /// so you can iterate over all and do some action if required.
  ///
  /// For example:
  /// ```dart
  /// final subscription = spinify.subscriptions.client['chat']!;
  /// await subscription.unsubscribe();
  /// ```
  ({
    Map<String, SpinifyClientSubscription> client,
    Map<String, SpinifyServerSubscription> server,
  }) get subscriptions;
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

/// Spinify metrics interface.
abstract interface class ISpinifyMetricsOwner {
  /// Get metrics of Spinify client.
  SpinifyMetrics get metrics;
}

/*
/// Spinify ping interface.
abstract interface class ISpinifyPing {
  /// Send ping to server.
  Future<void> ping();
}
 */
