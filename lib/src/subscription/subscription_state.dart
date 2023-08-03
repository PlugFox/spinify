import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:meta/meta.dart';

/// {@template subscription_state}
/// Subscription has 3 states:
///
/// - `unsubscribed`
/// - `subscribing`
/// - `subscribed`
///
/// When a new Subscription is created it has an `unsubscribed` state.
/// {@endtemplate}
/// {@category Subscription}
/// {@category Entity}
@immutable
sealed class SpinifySubscriptionState extends _$SpinifySubscriptionStateBase {
  /// {@macro subscription_state}
  const SpinifySubscriptionState(
      {required super.timestamp,
      required super.since,
      required super.recoverable});

  /// Unsubscribed
  /// {@macro subscription_state}
  factory SpinifySubscriptionState.unsubscribed({
    required int code,
    required String reason,
    DateTime? timestamp,
    ({fixnum.Int64 offset, String epoch})? since,
    bool recoverable,
  }) = SpinifySubscriptionState$Unsubscribed;

  /// Subscribing
  /// {@macro subscription_state}
  factory SpinifySubscriptionState.subscribing({
    DateTime? timestamp,
    ({fixnum.Int64 offset, String epoch})? since,
    bool recoverable,
  }) = SpinifySubscriptionState$Subscribing;

  /// Subscribed
  /// {@macro subscription_state}
  factory SpinifySubscriptionState.subscribed({
    DateTime? timestamp,
    ({fixnum.Int64 offset, String epoch})? since,
    bool recoverable,
    DateTime? ttl,
  }) = SpinifySubscriptionState$Subscribed;
}

/// Unsubscribed state
///
/// {@nodoc}
/// {@category Subscription}
/// {@category Entity}
final class SpinifySubscriptionState$Unsubscribed
    extends SpinifySubscriptionState with _$SpinifySubscriptionState {
  /// {@nodoc}
  SpinifySubscriptionState$Unsubscribed({
    required this.code,
    required this.reason,
    DateTime? timestamp,
    ({fixnum.Int64 offset, String epoch})? since,
    bool recoverable = false,
  }) : super(
            timestamp: timestamp ?? DateTime.now(),
            since: since,
            recoverable: recoverable);

  /// Unsubscribe code.
  final int code;

  /// Unsubscribe reason.
  final String reason;

  @override
  bool get isUnsubscribed => true;

  @override
  bool get isSubscribing => false;

  @override
  bool get isSubscribed => false;

  @override
  R map<R>({
    required SpinifySubscriptionStateMatch<R,
            SpinifySubscriptionState$Unsubscribed>
        unsubscribed,
    required SpinifySubscriptionStateMatch<R,
            SpinifySubscriptionState$Subscribing>
        subscribing,
    required SpinifySubscriptionStateMatch<R,
            SpinifySubscriptionState$Subscribed>
        subscribed,
  }) =>
      unsubscribed(this);

  @override
  int get hashCode => Object.hash(0, timestamp, since);

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  String toString() => 'unsubscribed';
}

/// Subscribing state
/// {@nodoc}
/// {@category Subscription}
/// {@category Entity}
final class SpinifySubscriptionState$Subscribing
    extends SpinifySubscriptionState with _$SpinifySubscriptionState {
  /// {@nodoc}
  SpinifySubscriptionState$Subscribing({
    DateTime? timestamp,
    ({fixnum.Int64 offset, String epoch})? since,
    bool recoverable = false,
  }) : super(
            timestamp: timestamp ?? DateTime.now(),
            since: since,
            recoverable: recoverable);

  @override
  bool get isUnsubscribed => false;

  @override
  bool get isSubscribing => true;

  @override
  bool get isSubscribed => false;

  @override
  R map<R>({
    required SpinifySubscriptionStateMatch<R,
            SpinifySubscriptionState$Unsubscribed>
        unsubscribed,
    required SpinifySubscriptionStateMatch<R,
            SpinifySubscriptionState$Subscribing>
        subscribing,
    required SpinifySubscriptionStateMatch<R,
            SpinifySubscriptionState$Subscribed>
        subscribed,
  }) =>
      subscribing(this);

  @override
  int get hashCode => Object.hash(1, timestamp, since);

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  String toString() => 'subscribing';
}

/// Subscribed state
/// {@nodoc}
/// {@category Subscription}
/// {@category Entity}
final class SpinifySubscriptionState$Subscribed extends SpinifySubscriptionState
    with _$SpinifySubscriptionState {
  /// {@nodoc}
  SpinifySubscriptionState$Subscribed({
    DateTime? timestamp,
    ({fixnum.Int64 offset, String epoch})? since,
    bool recoverable = false,
    this.ttl,
  }) : super(
            timestamp: timestamp ?? DateTime.now(),
            since: since,
            recoverable: recoverable);

  /// Time to live in seconds.
  final DateTime? ttl;

  @override
  bool get isUnsubscribed => false;

  @override
  bool get isSubscribing => false;

  @override
  bool get isSubscribed => true;

  @override
  R map<R>({
    required SpinifySubscriptionStateMatch<R,
            SpinifySubscriptionState$Unsubscribed>
        unsubscribed,
    required SpinifySubscriptionStateMatch<R,
            SpinifySubscriptionState$Subscribing>
        subscribing,
    required SpinifySubscriptionStateMatch<R,
            SpinifySubscriptionState$Subscribed>
        subscribed,
  }) =>
      subscribed(this);

  @override
  int get hashCode => Object.hash(2, timestamp, since, recoverable, ttl);

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  String toString() => 'subscribed';
}

/// {@nodoc}
base mixin _$SpinifySubscriptionState on SpinifySubscriptionState {}

/// Pattern matching for [SpinifySubscriptionState].
typedef SpinifySubscriptionStateMatch<R, S extends SpinifySubscriptionState> = R
    Function(S state);

/// {@nodoc}
@immutable
abstract base class _$SpinifySubscriptionStateBase {
  /// {@nodoc}
  const _$SpinifySubscriptionStateBase({
    required this.timestamp,
    required this.since,
    required this.recoverable,
  });

  /// Timestamp of state change.
  final DateTime timestamp;

  /// Stream Position
  final ({fixnum.Int64 offset, String epoch})? since;

  /// Whether channel is recoverable.
  final bool recoverable;

  /// Whether channel is unsubscribed.
  abstract final bool isUnsubscribed;

  /// Whether channel is subscribing.
  abstract final bool isSubscribing;

  /// Whether channel is subscribed.
  abstract final bool isSubscribed;

  /// Pattern matching for [SpinifySubscriptionState].
  R map<R>({
    required SpinifySubscriptionStateMatch<R,
            SpinifySubscriptionState$Unsubscribed>
        unsubscribed,
    required SpinifySubscriptionStateMatch<R,
            SpinifySubscriptionState$Subscribing>
        subscribing,
    required SpinifySubscriptionStateMatch<R,
            SpinifySubscriptionState$Subscribed>
        subscribed,
  });

  /// Pattern matching for [SpinifySubscriptionState].
  R maybeMap<R>({
    required R Function() orElse,
    SpinifySubscriptionStateMatch<R, SpinifySubscriptionState$Unsubscribed>?
        unsubscribed,
    SpinifySubscriptionStateMatch<R, SpinifySubscriptionState$Subscribing>?
        subscribing,
    SpinifySubscriptionStateMatch<R, SpinifySubscriptionState$Subscribed>?
        subscribed,
  }) =>
      map<R>(
        unsubscribed: unsubscribed ?? (_) => orElse(),
        subscribing: subscribing ?? (_) => orElse(),
        subscribed: subscribed ?? (_) => orElse(),
      );

  /// Pattern matching for [SpinifySubscriptionState].
  R? mapOrNull<R>({
    SpinifySubscriptionStateMatch<R, SpinifySubscriptionState$Unsubscribed>?
        unsubscribed,
    SpinifySubscriptionStateMatch<R, SpinifySubscriptionState$Subscribing>?
        subscribing,
    SpinifySubscriptionStateMatch<R, SpinifySubscriptionState$Subscribed>?
        subscribed,
  }) =>
      map<R?>(
        unsubscribed: unsubscribed ?? (_) => null,
        subscribing: subscribing ?? (_) => null,
        subscribed: subscribed ?? (_) => null,
      );
}
