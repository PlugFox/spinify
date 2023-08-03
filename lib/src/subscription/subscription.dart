import 'dart:async';

import 'package:spinify/src/model/history.dart';
import 'package:spinify/src/model/presence.dart';
import 'package:spinify/src/model/presence_stats.dart';
import 'package:spinify/src/model/pushes_stream.dart';
import 'package:spinify/src/model/stream_position.dart';
import 'package:spinify/src/subscription/subscription_state.dart';
import 'package:spinify/src/subscription/subscription_states_stream.dart';

/// {@template subscription}
/// Spinify subscription interface.
///
/// Client allows subscribing on channels.
/// This can be done by creating Subscription object.
///
/// ```dart
/// final subscription = client.newSubscription('chat');
/// await subscription.subscribe();
/// ```
/// When anewSubscription method is called Client allocates a new
/// Subscription instance and saves it in the internal subscription registry.
/// Having a registry of allocated subscriptions allows SDK to manage
/// resubscribes upon reconnecting to a server.
/// Centrifugo connectors do not allow creating two subscriptions to the
/// same channel – in this case, newSubscription can throw an exception.
///
/// Subscription has 3 states:
/// - [SpinifySubscriptionState$Unsubscribed]
/// - [SpinifySubscriptionState$Subscribing]
/// - [SpinifySubscriptionState$Subscribed]
///
/// When a new Subscription is created it has an unsubscribed state.
///
/// - For client-side subscriptions see [SpinifyClientSubscription].
/// - For server-side subscriptions see [SpinifyServerSubscription].
/// {@endtemplate}
/// {@category Subscription}
sealed class SpinifySubscription {
  /// Channel name.
  abstract final String channel;

  /// Current subscription state.
  abstract final SpinifySubscriptionState state;

  /// Offset of last successfully received message.
  abstract final SpinifyStreamPosition? since;

  /// Stream of subscription states.
  abstract final SpinifySubscriptionStateStream states;

  /// Stream of received pushes from Centrifugo server for a channel.
  abstract final SpinifyPushesStream stream;

  /// Await for subscription to be ready.
  /// Ready resolves when subscription successfully subscribed.
  /// Throws exceptions if called not in subscribing or subscribed state.
  FutureOr<void> ready();

  /// Publish data to current Subscription channel
  Future<void> publish(List<int> data);

  /// Fetch publication history inside a channel.
  /// Only for channels where history is enabled.
  Future<SpinifyHistory> history({
    int? limit,
    SpinifyStreamPosition? since,
    bool? reverse,
  });

  /// Fetch presence information inside a channel.
  Future<SpinifyPresence> presence();

  /// Fetch presence stats information inside a channel.
  Future<SpinifyPresenceStats> presenceStats();
}

/// {@template client_subscription}
/// # Centrifuge client-side subscription representation.
///
/// Client allows subscribing on channels.
/// This can be done by creating Subscription object.
///
/// When a newSubscription method is called Client allocates a new Subscription
/// instance and saves it in the internal subscription registry.
/// Having a registry of allocated subscriptions allows SDK to manage
/// resubscribes upon reconnecting to a server.
///
/// Centrifugo connectors do not allow creating two subscriptions
/// to the same channel – in this case, newSubscription can throw an exception.
///
/// ## Subscription has 3 states:
///
/// - `unsubscribed`
/// - `subscribing`
/// - `subscribed`
///
/// When a new Subscription is created it has an `unsubscribed` state.
///
/// ## Subscription common options
///
/// There are several common options available when
/// creating Subscription instance:
///
/// - option to set subscription token and callback to get subscription token
///   upon expiration (see below more details)
/// - option to set subscription data
///   (attached to every subscribe/resubscribe request)
/// - options to tweak resubscribe backoff algorithm
/// - option to start Subscription since known
///   Stream Position (i.e. attempt recovery on first subscribe)
/// - option to ask server to make subscription positioned
///   (if not forced by a server)
/// - option to ask server to make subscription recoverable
///   (if not forced by a server)
/// - option to ask server to push Join/Leave messages
///   (if not forced by a server)
///
/// ## Subscription methods
///
/// - subscribe() – start subscribing to a channel
/// - unsubscribe() - unsubscribe from a channel
/// - publish(data) - publish data to Subscription channel
/// - history(options) - request Subscription channel history
/// - presence() - request Subscription channel online presence information
/// - presenceStats() - request Subscription channel online presence stats
///   information (number of client connections and unique users in a channel).
///
/// {@endtemplate}
/// {@category Subscription}
/// {@subCategory Client-side}
abstract class SpinifyClientSubscription extends SpinifySubscription {
  /// Start subscribing to a channel
  Future<void> subscribe();

  /// Unsubscribe from a channel
  Future<void> unsubscribe([
    int code = 0,
    String reason = 'unsubscribe called',
  ]);
}

/// {@template server_subscription}
/// Centrifuge server-side subscription representation.
///
/// We encourage using client-side subscriptions where possible
/// as they provide a better control and isolation from connection.
/// But in some cases you may want to use server-side subscriptions
/// (i.e. subscriptions created by server upon connection establishment).
///
/// Technically, client SDK keeps server-side subscriptions
/// in internal registry, similar to client-side subscriptions
/// but without possibility to control them.
/// {@endtemplate}
/// {@category Subscription}
/// {@subCategory Server-side}
abstract class SpinifyServerSubscription extends SpinifySubscription {}
