import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:meta/meta.dart';

import 'stream_position.dart';

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
    SpinifyStreamPosition? since,
    bool recoverable,
  }) = SpinifySubscriptionState$Unsubscribed;

  /// Subscribing
  /// {@macro subscription_state}
  factory SpinifySubscriptionState.subscribing({
    DateTime? timestamp,
    SpinifyStreamPosition? since,
    bool recoverable,
  }) = SpinifySubscriptionState$Subscribing;

  /// Subscribed
  /// {@macro subscription_state}
  factory SpinifySubscriptionState.subscribed({
    DateTime? timestamp,
    SpinifyStreamPosition? since,
    bool recoverable,
    DateTime? ttl,
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
    required this.code,
    required this.reason,
    DateTime? timestamp,
    super.since,
    super.recoverable = false,
  }) : super(timestamp: timestamp ?? DateTime.now());

  @override
  String get type => 'unsubscribed';

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
  Map<String, Object?> toJson() => <String, Object?>{
        ...super.toJson(),
        'code': code,
        'reason': reason,
      };

  @override
  int get hashCode => Object.hash(0, timestamp, since);

  @override
  bool operator ==(Object other) => identical(this, other);

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
    super.since,
    super.recoverable = false,
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
  int get hashCode => Object.hash(1, timestamp, since);

  @override
  bool operator ==(Object other) => identical(this, other);

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
    DateTime? timestamp,
    super.since,
    super.recoverable = false,
    this.ttl,
  }) : super(timestamp: timestamp ?? DateTime.now());

  @override
  String get type => 'subscribed';

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
  Map<String, Object?> toJson() => <String, Object?>{
        ...super.toJson(),
        if (ttl != null) 'ttl': ttl?.toUtc().toIso8601String(),
      };

  @override
  int get hashCode => Object.hash(2, timestamp, since, recoverable, ttl);

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  String toString() => r'SpinifySubscriptionState$Subscribed{}';
}

/// Pattern matching for [SpinifySubscriptionState].
/// {@category Entity}
typedef SpinifySubscriptionStateMatch<R, S extends SpinifySubscriptionState> = R
    Function(S state);

@immutable
abstract base class _$SpinifySubscriptionStateBase {
  const _$SpinifySubscriptionStateBase({
    required this.timestamp,
    required this.since,
    required this.recoverable,
  });

  /// Represents the current state type.
  abstract final String type;

  /// Timestamp of state change.
  final DateTime timestamp;

  /// Stream Position
  final SpinifyStreamPosition? since;

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

  Map<String, Object?> toJson() => <String, Object?>{
        'type': type,
        'timestamp': timestamp.toUtc().toIso8601String(),
        if (since != null)
          'since': switch (since) {
            (:fixnum.Int64 offset, :String epoch) => <String, Object>{
                'offset': offset,
                'epoch': epoch,
              },
            _ => null,
          },
        'recoverable': recoverable,
      };
}
