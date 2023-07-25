import 'dart:async';

import 'package:centrifuge_dart/interface.dart';
import 'package:centrifuge_dart/src/model/subscription_states_stream.dart';
import 'package:fixnum/fixnum.dart' as fixnum;

/// {@template subscription}
/// Centrifuge subscription interface.
/// {@endtemplate}
/// {@category Subscription}
/// {@category Entity}
abstract interface class ICentrifugeSubscription {
  /// Channel name.
  abstract final String channel;
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
/// {@category Entity}
abstract interface class CentrifugeClientSubscription
    implements ICentrifugeSubscription {
  @override
  abstract final String channel;

  /// Current subscription state.
  abstract final CentrifugeSubscriptionState state;

  /// Stream of subscription states.
  abstract final CentrifugeSubscriptionStateStream states;

  /// Stream of publications.
  abstract final Stream<CentrifugePublication> publications;

  /// Await for subscription to be ready.
  FutureOr<void> ready();

  /// Start subscribing to a channel
  Future<void> subscribe();

  /// Unsubscribe from a channel
  Future<void> unsubscribe();

  @override
  String toString() => 'CentrifugeClientSubscription{channel: $channel}';
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
/// {@category Entity}
final class CentrifugeServerSubscription implements ICentrifugeSubscription {
  /// {@macro server_subscription}
  const CentrifugeServerSubscription({
    required this.channel,
    required this.recoverable,
    required this.offset,
    required this.epoch,
  });

  @override
  final String channel;

  /// Recoverable flag.
  final bool recoverable;

  /// Offset.
  final fixnum.Int64 offset;

  /// Epoch.
  final String epoch;

  /* publish(channel, data)
  history(channel, options)
  presence(channel)
  presenceStats(channel) */

  @override
  String toString() => 'CentrifugeServerSubscription{channel: $channel}';
}
