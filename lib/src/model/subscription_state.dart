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
sealed class CentrifugeSubscriptionState
    extends _$CentrifugeSubscriptionStateBase {
  /// {@macro subscription_state}
  const CentrifugeSubscriptionState(super.timestamp, super.since);

  /// Unsubscribed
  /// {@macro subscription_state}
  factory CentrifugeSubscriptionState.unsubscribed({
    DateTime? timestamp,
    ({fixnum.Int64 offset, String epoch})? since,
  }) = CentrifugeSubscriptionState$Unsubscribed;

  /// Subscribing
  /// {@macro subscription_state}
  factory CentrifugeSubscriptionState.subscribing({
    DateTime? timestamp,
    ({fixnum.Int64 offset, String epoch})? since,
  }) = CentrifugeSubscriptionState$Subscribing;

  /// Subscribed
  /// {@macro subscription_state}
  factory CentrifugeSubscriptionState.subscribed({
    DateTime? timestamp,
    ({fixnum.Int64 offset, String epoch})? since,
  }) = CentrifugeSubscriptionState$Subscribed;
}

/// Unsubscribed state
///
/// {@nodoc}
/// {@category Subscription}
/// {@category Entity}
final class CentrifugeSubscriptionState$Unsubscribed
    extends CentrifugeSubscriptionState with _$CentrifugeSubscriptionState {
  /// {@nodoc}
  CentrifugeSubscriptionState$Unsubscribed({
    DateTime? timestamp,
    ({fixnum.Int64 offset, String epoch})? since,
  }) : super(timestamp ?? DateTime.now(), since);

  @override
  R map<R>({
    required CentrifugeSubscriptionStateMatch<R,
            CentrifugeSubscriptionState$Unsubscribed>
        unsubscribed,
    required CentrifugeSubscriptionStateMatch<R,
            CentrifugeSubscriptionState$Subscribing>
        subscribing,
    required CentrifugeSubscriptionStateMatch<R,
            CentrifugeSubscriptionState$Subscribed>
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
final class CentrifugeSubscriptionState$Subscribing
    extends CentrifugeSubscriptionState with _$CentrifugeSubscriptionState {
  /// {@nodoc}
  CentrifugeSubscriptionState$Subscribing({
    DateTime? timestamp,
    ({fixnum.Int64 offset, String epoch})? since,
  }) : super(timestamp ?? DateTime.now(), since);

  @override
  R map<R>({
    required CentrifugeSubscriptionStateMatch<R,
            CentrifugeSubscriptionState$Unsubscribed>
        unsubscribed,
    required CentrifugeSubscriptionStateMatch<R,
            CentrifugeSubscriptionState$Subscribing>
        subscribing,
    required CentrifugeSubscriptionStateMatch<R,
            CentrifugeSubscriptionState$Subscribed>
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
final class CentrifugeSubscriptionState$Subscribed
    extends CentrifugeSubscriptionState with _$CentrifugeSubscriptionState {
  /// {@nodoc}
  CentrifugeSubscriptionState$Subscribed({
    DateTime? timestamp,
    ({fixnum.Int64 offset, String epoch})? since,
  }) : super(timestamp ?? DateTime.now(), since);

  @override
  R map<R>({
    required CentrifugeSubscriptionStateMatch<R,
            CentrifugeSubscriptionState$Unsubscribed>
        unsubscribed,
    required CentrifugeSubscriptionStateMatch<R,
            CentrifugeSubscriptionState$Subscribing>
        subscribing,
    required CentrifugeSubscriptionStateMatch<R,
            CentrifugeSubscriptionState$Subscribed>
        subscribed,
  }) =>
      subscribed(this);

  @override
  int get hashCode => Object.hash(2, timestamp, since);

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  String toString() => 'subscribed';
}

/// {@nodoc}
base mixin _$CentrifugeSubscriptionState on CentrifugeSubscriptionState {}

/// Pattern matching for [CentrifugeSubscriptionState].
typedef CentrifugeSubscriptionStateMatch<R,
        S extends CentrifugeSubscriptionState>
    = R Function(S state);

/// {@nodoc}
@immutable
abstract base class _$CentrifugeSubscriptionStateBase {
  /// {@nodoc}
  const _$CentrifugeSubscriptionStateBase(this.timestamp, this.since);

  /// Timestamp of state change.
  final DateTime timestamp;

  /// Stream Position
  final ({fixnum.Int64 offset, String epoch})? since;

  /// Pattern matching for [CentrifugeSubscriptionState].
  R map<R>({
    required CentrifugeSubscriptionStateMatch<R,
            CentrifugeSubscriptionState$Unsubscribed>
        unsubscribed,
    required CentrifugeSubscriptionStateMatch<R,
            CentrifugeSubscriptionState$Subscribing>
        subscribing,
    required CentrifugeSubscriptionStateMatch<R,
            CentrifugeSubscriptionState$Subscribed>
        subscribed,
  });

  /// Pattern matching for [CentrifugeSubscriptionState].
  R maybeMap<R>({
    required R Function() orElse,
    CentrifugeSubscriptionStateMatch<R,
            CentrifugeSubscriptionState$Unsubscribed>?
        unsubscribed,
    CentrifugeSubscriptionStateMatch<R,
            CentrifugeSubscriptionState$Subscribing>?
        subscribing,
    CentrifugeSubscriptionStateMatch<R, CentrifugeSubscriptionState$Subscribed>?
        subscribed,
  }) =>
      map<R>(
        unsubscribed: unsubscribed ?? (_) => orElse(),
        subscribing: subscribing ?? (_) => orElse(),
        subscribed: subscribed ?? (_) => orElse(),
      );

  /// Pattern matching for [CentrifugeSubscriptionState].
  R? mapOrNull<R>({
    CentrifugeSubscriptionStateMatch<R,
            CentrifugeSubscriptionState$Unsubscribed>?
        unsubscribed,
    CentrifugeSubscriptionStateMatch<R,
            CentrifugeSubscriptionState$Subscribing>?
        subscribing,
    CentrifugeSubscriptionStateMatch<R, CentrifugeSubscriptionState$Subscribed>?
        subscribed,
  }) =>
      map<R?>(
        unsubscribed: unsubscribed ?? (_) => null,
        subscribing: subscribing ?? (_) => null,
        subscribed: subscribed ?? (_) => null,
      );
}
