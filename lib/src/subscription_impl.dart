import 'dart:async';

import 'package:meta/meta.dart';

import 'model/channel_event.dart';
import 'model/channel_events.dart';
import 'model/exception.dart';
import 'model/history.dart';
import 'model/presence_stats.dart';
import 'model/stream_position.dart';
import 'model/subscription_config.dart';
import 'model/subscription_state.dart';
import 'model/subscription_states_stream.dart';
import 'spinify_interface.dart';
import 'subscription_interface.dart';

@internal
final class SpinifyClientSubscriptionImpl implements SpinifyClientSubscription {
  SpinifyClientSubscriptionImpl({
    required ISpinify client,
    required this.channel,
    required this.config,
  }) : _clientWR = WeakReference<ISpinify>(client);

  @override
  final String channel;

  @override
  final SpinifySubscriptionConfig config;

  /// Spinify client weak reference.
  final WeakReference<ISpinify> _clientWR;
  ISpinify get _client {
    final target = _clientWR.target;
    if (target == null) {
      throw SpinifySubscriptionException(
        channel: channel,
        message: 'Client is closed',
      );
    }
    return target;
  }

  @override
  SpinifyStreamPosition? get since => throw UnimplementedError();

  @override
  SpinifySubscriptionState get state => throw UnimplementedError();

  @override
  SpinifySubscriptionStateStream get states => throw UnimplementedError();

  @override
  ChannelEvents<SpinifyChannelEvent> get stream =>
      _client.stream.filter(channel: channel);

  @override
  Future<SpinifyHistory> history({
    int? limit,
    SpinifyStreamPosition? since,
    bool? reverse,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SpinifyPresence> presence() {
    throw UnimplementedError();
  }

  @override
  Future<SpinifyPresenceStats> presenceStats() {
    throw UnimplementedError();
  }

  @override
  Future<void> publish(List<int> data) {
    throw UnimplementedError();
  }

  @override
  FutureOr<void> ready() {
    throw UnimplementedError();
  }

  @override
  Future<void> subscribe() {
    throw UnimplementedError();
  }

  @override
  Future<void> unsubscribe([
    int code = 0,
    String reason = 'unsubscribe called',
  ]) {
    throw UnimplementedError();
  }

  Future<void> close() async {}
}
