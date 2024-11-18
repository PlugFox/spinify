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
  const SpinifySubscriptionState({required super.timestamp});

  /// Unsubscribed
  /// {@macro subscription_state}
  factory SpinifySubscriptionState.unsubscribed({
    DateTime? timestamp,
  }) = SpinifySubscriptionState$Unsubscribed;

  /// Subscribing
  /// {@macro subscription_state}
  factory SpinifySubscriptionState.subscribing({
    DateTime? timestamp,
  }) = SpinifySubscriptionState$Subscribing;

  /// Subscribed
  /// {@macro subscription_state}
  factory SpinifySubscriptionState.subscribed({
    List<int>? data,
    DateTime? timestamp,
  }) = SpinifySubscriptionState$Subscribed;
}

/// Unsubscribed state
///
/// {@macro subscription_state}
/// {@category Subscription}
/// {@category Entity}
final class SpinifySubscriptionState$Unsubscribed
    extends SpinifySubscriptionState {
  /// {@macro subscription_state}
  SpinifySubscriptionState$Unsubscribed({
    DateTime? timestamp,
  }) : super(timestamp: timestamp ?? DateTime.now());

  @override
  String get type => 'unsubscribed';

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
  int get hashCode => 0 + timestamp.microsecondsSinceEpoch * 10;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpinifySubscriptionState$Unsubscribed &&
          other.timestamp.isAtSameMomentAs(timestamp);

  @override
  String toString() => r'SpinifySubscriptionState$Unsubscribed{}';
}

/// Subscribing state
///
/// {@macro subscription_state}
/// {@category Subscription}
/// {@category Entity}
final class SpinifySubscriptionState$Subscribing
    extends SpinifySubscriptionState {
  /// {@macro subscription_state}
  SpinifySubscriptionState$Subscribing({
    DateTime? timestamp,
  }) : super(timestamp: timestamp ?? DateTime.now());

  @override
  String get type => 'subscribing';

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
  int get hashCode => 1 + timestamp.microsecondsSinceEpoch * 10;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpinifySubscriptionState$Subscribing &&
          other.timestamp.isAtSameMomentAs(timestamp);

  @override
  String toString() => r'SpinifySubscriptionState$Subscribing{}';
}

/// Subscribed state
///
/// {@macro subscription_state}
/// {@category Subscription}
/// {@category Entity}
final class SpinifySubscriptionState$Subscribed
    extends SpinifySubscriptionState {
  /// {@macro subscription_state}
  SpinifySubscriptionState$Subscribed({
    this.data,
    DateTime? timestamp,
  }) : super(timestamp: timestamp ?? DateTime.now());

  /// Data attached to current subscription.
  final List<int>? data;

  @override
  String get type => 'subscribed';

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
  int get hashCode => 2 + timestamp.microsecondsSinceEpoch * 10;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpinifySubscriptionState$Subscribed &&
          other.timestamp.isAtSameMomentAs(timestamp);

  @override
  String toString() => r'SpinifySubscriptionState$Subscribed{}';
}

/// Pattern matching for [SpinifySubscriptionState].
/// {@category Entity}
typedef SpinifySubscriptionStateMatch<R, S extends SpinifySubscriptionState> = R
    Function(S state);

@immutable
abstract base class _$SpinifySubscriptionStateBase
    implements Comparable<_$SpinifySubscriptionStateBase> {
  const _$SpinifySubscriptionStateBase({
    required this.timestamp,
  });

  /// Represents the current state type.
  abstract final String type;

  /// Timestamp of state change.
  final DateTime timestamp;

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

  @override
  int compareTo(_$SpinifySubscriptionStateBase other) =>
      timestamp.compareTo(other.timestamp);
}
