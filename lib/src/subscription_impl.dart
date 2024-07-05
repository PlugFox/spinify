import 'dart:async';

import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:meta/meta.dart';

import 'model/channel_event.dart';
import 'model/channel_events.dart';
import 'model/client_info.dart';
import 'model/config.dart';
import 'model/exception.dart';
import 'model/history.dart';
import 'model/presence_stats.dart';
import 'model/state.dart';
import 'model/stream_position.dart';
import 'model/subscription_config.dart';
import 'model/subscription_state.dart';
import 'model/subscription_states.dart';
import 'spinify_interface.dart';
import 'subscription_interface.dart';

@internal
abstract base class SpinifySubscriptionBase implements SpinifySubscription {
  SpinifySubscriptionBase({
    required ISpinify client,
    required this.channel,
    required this.recoverable,
    required this.epoch,
    required this.offset,
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

  SpinifyLogger? get _logger => _client.config.logger;

  SpinifySubscriptionState _state = SpinifySubscriptionState.unsubscribed();

  final StreamController<SpinifySubscriptionState> _stateController =
      StreamController<SpinifySubscriptionState>.broadcast();

  final StreamController<SpinifyChannelEvent> _eventController =
      StreamController<SpinifyChannelEvent>.broadcast();

  @override
  bool recoverable;

  @override
  String epoch;

  @override
  fixnum.Int64 offset;

  @override
  SpinifySubscriptionState get state => _state;

  @override
  SpinifySubscriptionStates get states =>
      SpinifySubscriptionStates(_stateController.stream);

  @override
  SpinifyChannelEvents<SpinifyChannelEvent> get stream =>
      SpinifyChannelEvents(_eventController.stream);

  @mustCallSuper
  void onEvent(SpinifyChannelEvent event) {
    assert(
      event.channel == channel,
      'Subscription "$channel" received event for another channel',
    );
    _eventController.add(event);
    _logger?.call(
      const SpinifyLogLevel.debug(),
      'subscription_event_received',
      'Subscription "$channel" received ${event.type} event',
      <String, Object?>{
        'channel': channel,
        'subscription': this,
        'event': event,
      },
    );
  }

  @mustCallSuper
  void setState(SpinifySubscriptionState state) {
    if (_state == state) return;
    _stateController.add(_state = state);
    _logger?.call(
      const SpinifyLogLevel.config(),
      'subscription_state_changed',
      'Subscription "$channel" state changed to ${state.type}',
      <String, Object?>{
        'channel': channel,
        'subscription': this,
        'state': _state,
      },
    );
  }

  @mustCallSuper
  void close() {
    _stateController.close().ignore();
    _eventController.close().ignore();
    assert(_state.isUnsubscribed,
        'Subscription "$channel" is not unsubscribed before closing');
  }

  @override
  Future<void> ready() async {
    if (_client.isClosed)
      throw SpinifySubscriptionException(
        channel: channel,
        message: 'Client is closed',
      );
    if (_state.isSubscribed) return;
    if (_stateController.isClosed)
      throw SpinifySubscriptionException(
        channel: channel,
        message: 'Subscription is closed permanently',
      );
    final state = await _stateController.stream
        .firstWhere((state) => !state.isSubscribing);
    if (!state.isSubscribed)
      throw SpinifySubscriptionException(
        channel: channel,
        message: 'Subscription failed to subscribe',
      );
  }

  @override
  Future<SpinifyHistory> history({
    int? limit,
    SpinifyStreamPosition? since,
    bool? reverse,
  }) async {
    await ready().timeout(_client.config.timeout);
    return _client.history(
      channel,
      limit: limit,
      since: since,
      reverse: reverse,
    );
  }

  @override
  Future<Map<String, SpinifyClientInfo>> presence() async {
    await ready().timeout(_client.config.timeout);
    return _client.presence(channel);
  }

  @override
  Future<SpinifyPresenceStats> presenceStats() async {
    await ready().timeout(_client.config.timeout);
    return _client.presenceStats(channel);
  }

  @override
  Future<void> publish(List<int> data) async {
    await ready().timeout(_client.config.timeout);
    return _client.publish(channel, data);
  }
}

@internal
final class SpinifyClientSubscriptionImpl extends SpinifySubscriptionBase
    implements SpinifyClientSubscription {
  SpinifyClientSubscriptionImpl({
    required super.client,
    required super.channel,
    required this.config,
  }) : super(
          recoverable: config.recoverable,
          epoch: config.since?.epoch ?? '',
          offset: config.since?.offset ?? fixnum.Int64.ZERO,
        );

  @override
  final SpinifySubscriptionConfig config;

  /// Interactively subscribes to the channel.
  @override
  Future<void> subscribe() async {
    // Check if the client is connected
    switch (_client.state) {
      case SpinifyState$Connected _:
        break;
      case SpinifyState$Connecting _:
      case SpinifyState$Disconnected _:
        await _client.ready();
      case SpinifyState$Closed _:
        throw SpinifySubscriptionException(
          channel: channel,
          message: 'Client is closed',
        );
    }

    // Check if the subscription is already subscribed
    switch (state) {
      case SpinifySubscriptionState$Subscribed _:
        return;
      case SpinifySubscriptionState$Subscribing _:
        await ready();
      case SpinifySubscriptionState$Unsubscribed _:
        await _resubscribe();
    }
  }

  @override
  Future<void> unsubscribe([
    int code = 0,
    String reason = 'unsubscribe called',
  ]) async {
    if (_state.isUnsubscribed) return Future.value();
    //await ready().timeout(_client.config.timeout);
    throw UnimplementedError();
    // TODO(plugfox): implement unsubscribe, remove resubscribe timer
  }

  /// `SubscriptionImpl{}._resubscribe()` from `centrifuge` package
  Future<void> _resubscribe() async {
    if (!_state.isUnsubscribed) return;
    setState(SpinifySubscriptionState$Subscribing());
  }
}

@internal
final class SpinifyServerSubscriptionImpl extends SpinifySubscriptionBase
    implements SpinifyServerSubscription {
  SpinifyServerSubscriptionImpl({
    required super.client,
    required super.channel,
    required super.recoverable,
    required super.epoch,
    required super.offset,
  });

  @override
  SpinifyChannelEvents<SpinifyChannelEvent> get stream =>
      _client.stream.filter(channel: channel);
}
