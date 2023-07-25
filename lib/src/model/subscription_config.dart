import 'dart:async';

import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:meta/meta.dart';

/// Token used for subscription.
typedef CentrifugeSubscriptionToken = String;

/// Callback to get token for subscription.
/// If method returns null then subscription will be established without token.
typedef CentrifugeSubscriptionTokenCallback
    = FutureOr<CentrifugeSubscriptionToken?> Function();

/// {@template subscription_config}
/// Subscription common options
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
/// {@endtemplate}
/// {@category Subscription}
/// {@category Entity}
@immutable
class CentrifugeSubscriptionConfig {
  /// {@macro subscription_config}
  const CentrifugeSubscriptionConfig({
    this.getToken,
    this.data,
    this.resubscribeInterval = (
      min: const Duration(milliseconds: 500),
      max: const Duration(seconds: 20),
    ),
    this.since,
    this.positioned = false,
    this.recoverable = false,
    this.joinLeave = false,
    this.timeout = const Duration(seconds: 15),
  });

  /// Create a default config
  ///
  /// {@macro subscription_config}
  @literal
  const factory CentrifugeSubscriptionConfig.byDefault() =
      CentrifugeSubscriptionConfig;

  /// Callback to get token for subscription
  /// and get updated token upon expiration.
  final CentrifugeSubscriptionTokenCallback? getToken;

  /// Data to send with subscription request.
  /// Subscription [data] is attached to every subscribe/resubscribe request.
  final List<int>? data;

  /// Resubscribe backoff algorithm
  final ({Duration min, Duration max}) resubscribeInterval;

  /// start Subscription [since] known Stream Position
  /// (i.e. attempt recovery on first subscribe)
  final ({fixnum.Int64 offset, String epoch})? since;

  /// Ask server to make subscription [positioned] (if not forced by a server)
  final bool positioned;

  /// Ask server to make subscription [recoverable] (if not forced by a server)
  final bool recoverable;

  /// Ask server to push Join/Leave messages (if not forced by a server)
  final bool joinLeave;

  /// Maximum time to wait for the subscription to be established.
  /// If not specified, the timeout will be 15 seconds.
  final Duration timeout;
}
