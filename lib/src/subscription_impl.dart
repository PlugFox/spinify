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
abstract base class SpinifySubscriptionBase implements SpinifySubscription {
  SpinifySubscriptionBase({
    required ISpinify client,
    required this.channel,
  }) : _clientWR = WeakReference<ISpinify>(client);

  @override
  final String channel;

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

  final StreamController<SpinifyChannelEvent> _stateController =
      StreamController<SpinifyChannelEvent>.broadcast();

  final StreamController<SpinifyChannelEvent> _eventController =
      StreamController<SpinifyChannelEvent>.broadcast();

  @override
  SpinifySubscriptionState get state => throw UnimplementedError();

  @override
  SpinifySubscriptionStateStream get states => throw UnimplementedError();

  @override
  ChannelEvents<SpinifyChannelEvent> get stream =>
      ChannelEvents(_eventController.stream);

  @mustCallSuper
  void onEvent(SpinifyChannelEvent event) {
    _eventController.add(event);
    // TODO(plugfox): update since position
  }

  @mustCallSuper
  void close() {
    _stateController.close().ignore();
    _eventController.close().ignore();
  }
}

@internal
final class SpinifyClientSubscriptionImpl extends SpinifySubscriptionBase
    implements SpinifyClientSubscription {
  SpinifyClientSubscriptionImpl({
    required super.client,
    required super.channel,
    required this.config,
  });

  @override
  final SpinifySubscriptionConfig config;

  // TODO(plugfox): set from client
  @override
  SpinifyStreamPosition? get since => throw UnimplementedError();

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
}

@internal
final class SpinifyServerSubscriptionImpl extends SpinifySubscriptionBase
    implements SpinifyServerSubscription {
  SpinifyServerSubscriptionImpl({
    required super.client,
    required super.channel,
  });

  // TODO(plugfox): set from client
  @override
  SpinifyStreamPosition? get since => throw UnimplementedError();

  // TODO(plugfox): set from client
  @override
  SpinifySubscriptionState get state => throw UnimplementedError();

  // TODO(plugfox): get from client
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
}
