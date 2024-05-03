import 'dart:async';

import 'package:meta/meta.dart';

import '../src.old/subscription/subscription.dart';
import 'event_bus.dart';
import 'model/config.dart';
import 'model/history.dart';
import 'model/metrics.dart';
import 'model/presence.dart';
import 'model/presence_stats.dart';
import 'model/pushes_stream.dart';
import 'model/state.dart';
import 'model/states_stream.dart';
import 'model/stream_position.dart';
import 'model/subscription_config.dart';
import 'spinify_interface.dart';

/// Spinify client events.
@internal
abstract interface class ClientEvents {
  static const String prefix = 'client';
  static const String init = '${prefix}_init';
  static const String close = '${prefix}_close';
}

/// Base class for Spinify client.
abstract base class SpinifyBase implements ISpinify {
  /// Create a new Spinify client.
  SpinifyBase(this.config) : id = _idCounter++ {
    _bucket = SpinifyEventBus.instance.registerClient(this);
    _init();
  }

  /// Unique client ID counter for Spinify clients.
  static int _idCounter = 0;

  @override
  final int id;

  @override
  bool get isClosed => _isClosed;
  bool _isClosed = false;

  /// Spinify config.
  @override
  @nonVirtual
  final SpinifyConfig config;

  /// Event Bus Bucket for client events and event subscriptions.
  late final SpinifyEventBus$Bucket _bucket;

  @mustCallSuper
  void _init() {
    _bucket
      ..pushEvent(ClientEvents.init)
      ..subscribe(ClientEvents.close, _onClose);
  }

  @mustCallSuper
  Future<void> _onClose(_) async {
    _isClosed = true;
    SpinifyEventBus.instance.unregisterClient(this);
  }

  @override
  @mustCallSuper
  Future<void> close() async {
    if (_isClosed) return;
    await _bucket.pushEvent(ClientEvents.close);
  }

  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  int get hashCode => id;

  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  bool operator ==(Object other) =>
      identical(this, other) || other is SpinifyBase && id == other.id;

  @override
  String toString() => 'Spinify{}';
}

base mixin SpinifyStateMixin on SpinifyBase {
  @override
  SpinifyState get state => throw UnimplementedError();

  @override
  SpinifyStatesStream get states => throw UnimplementedError();
}

base mixin SpinifyConnectionMixin on SpinifyBase {
  @override
  Future<void> connect(String url) {
    throw UnimplementedError();
  }

  @override
  FutureOr<void> ready() {
    throw UnimplementedError();
  }

  @override
  Future<void> disconnect([int code = 0, String reason = 'Disconnect called']) {
    throw UnimplementedError();
  }
}

base mixin SpinifySendMixin on SpinifyBase {
  @override
  Future<void> send(List<int> data) {
    throw UnimplementedError();
  }
}

base mixin SpinifyClientSubscriptionMixin on SpinifyBase {
  @override
  ({
    Map<String, SpinifyClientSubscription> client,
    Map<String, SpinifyServerSubscription> server
  }) get subscriptions => throw UnimplementedError();

  @override
  SpinifyClientSubscription? getSubscription(String channel) {
    throw UnimplementedError();
  }

  @override
  SpinifyClientSubscription newSubscription(String channel,
      [SpinifySubscriptionConfig? config]) {
    throw UnimplementedError();
  }

  @override
  Future<void> removeSubscription(SpinifyClientSubscription subscription) {
    throw UnimplementedError();
  }
}

base mixin SpinifyServerSubscriptionMixin on SpinifyBase {}

base mixin SpinifyPublicationsMixin on SpinifyBase {
  @override
  Future<void> publish(String channel, List<int> data) {
    throw UnimplementedError();
  }
}

base mixin SpinifyPresenceMixin on SpinifyBase {
  @override
  Future<SpinifyPresence> presence(String channel) {
    throw UnimplementedError();
  }

  @override
  Future<SpinifyPresenceStats> presenceStats(String channel) {
    throw UnimplementedError();
  }
}

base mixin SpinifyHistoryMixin on SpinifyBase {
  @override
  Future<SpinifyHistory> history(String channel,
      {int? limit, SpinifyStreamPosition? since, bool? reverse}) {
    throw UnimplementedError();
  }
}

base mixin SpinifyRPCMixin on SpinifyBase {
  @override
  Future<List<int>> rpc(String method, List<int> data) {
    throw UnimplementedError();
  }
}

base mixin SpinifyMetricsMixin on SpinifyBase {
  @override
  SpinifyMetrics get metrics => throw UnimplementedError();
}

/// {@template spinify}
/// Spinify client for Centrifuge.
///
/// Centrifugo SDKs use WebSocket as the main data transport and send/receive
/// messages encoded according to our bidirectional protocol.
/// That protocol is built on top of the Protobuf schema
/// (both JSON and binary Protobuf formats are supported).
/// It provides asynchronous communication, sending RPC,
/// multiplexing subscriptions to channels, etc.
///
/// Client SDK wraps the protocol and exposes a set of APIs to developers.
///
/// Client connection has 4 states:
/// - [SpinifyState$Disconnected]
/// - [SpinifyState$Connecting]
/// - [SpinifyState$Connected]
/// - [SpinifyState$Closed]
///
/// {@endtemplate}
/// {@category Client}
final class Spinify extends SpinifyBase
    with
        SpinifyStateMixin,
        SpinifyConnectionMixin,
        SpinifySendMixin,
        SpinifyClientSubscriptionMixin,
        SpinifyServerSubscriptionMixin,
        SpinifyPublicationsMixin,
        SpinifyPresenceMixin,
        SpinifyHistoryMixin,
        SpinifyRPCMixin,
        SpinifyMetricsMixin {
  /// {@macro spinify}
  Spinify([SpinifyConfig? config]) : super(config ?? SpinifyConfig.byDefault());

  /// Create client and connect.
  ///
  /// {@macro spinify}
  factory Spinify.connect(String url, [SpinifyConfig? config]) =>
      Spinify(config)..connect(url);

  @override
  SpinifyPushesStream get stream => throw UnimplementedError();
}
