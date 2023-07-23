import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:meta/meta.dart';

/// {@template subscription}
/// Centrifuge subscription interface.
/// {@endtemplate}
abstract interface class ICentrifugeSubscription {
  /// Channel name.
  abstract final String channel;
}

/// {@template client_subscription}
/// Centrifuge client-side subscription representation.
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
/// Subscription has 3 states:
///
/// - `unsubscribed`
/// - `subscribing`
/// - `subscribed`
///
/// When a new Subscription is created it has an `unsubscribed` state.
/// {@endtemplate}
@immutable
final class CentrifugeClientSubscription implements ICentrifugeSubscription {
  /// {@macro client_subscription}
  const CentrifugeClientSubscription({
    required this.channel,
  });

  @override
  final String channel;

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
@immutable
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
