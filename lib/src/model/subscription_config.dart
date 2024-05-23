import 'dart:async';

import 'package:meta/meta.dart';

import 'stream_position.dart';

/// Token used for subscription.
/// {@category Subscription}
/// {@category Entity}
typedef SpinifySubscriptionToken = String;

/// Callback to get token for subscription.
/// If method returns null then subscription will be established without token.
/// {@category Subscription}
/// {@category Entity}
typedef SpinifySubscriptionTokenCallback = FutureOr<SpinifySubscriptionToken?>
    Function();

/// Callback to set subscription payload data.
///
/// If method returns null then no payload will be sent at subscribe time.

/// {@category Subscription}
/// {@category Entity}
typedef SpinifySubscribePayloadCallback = FutureOr<List<int>?> Function();

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
class SpinifySubscriptionConfig {
  /// {@macro subscription_config}
  const SpinifySubscriptionConfig({
    this.getToken,
    this.getPayload,
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
  const factory SpinifySubscriptionConfig.byDefault() =
      SpinifySubscriptionConfig;

  /// Callback to get token for subscription
  /// and get updated token upon expiration.
  final SpinifySubscriptionTokenCallback? getToken;

  /// Data to send with subscription request.
  /// Subscription `data` is attached to every subscribe/resubscribe request.
  final SpinifySubscribePayloadCallback? getPayload;

  /// Resubscribe backoff algorithm
  final ({Duration min, Duration max}) resubscribeInterval;

  /// Start Subscription [since] known Stream Position
  /// (i.e. attempt recovery on first subscribe)
  final SpinifyStreamPosition? since;

  /// Ask server to make subscription [positioned] (if not forced by a server)
  final bool positioned;

  /// Ask server to make subscription [recoverable] (if not forced by a server)
  final bool recoverable;

  /// Ask server to push Join/Leave messages (if not forced by a server)
  final bool joinLeave;

  /// Maximum time to wait for the subscription to be established.
  /// If not specified, the timeout will be 15 seconds.
  final Duration timeout;

  @override
  String toString() => 'SpinifySubscriptionConfig{}';
}
