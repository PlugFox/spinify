import 'dart:async';

import 'package:meta/meta.dart';
import 'package:spinify/src/client/state.dart';
import 'package:spinify/src/model/event.dart';
import 'package:spinify/src/model/history.dart';
import 'package:spinify/src/model/presence.dart';
import 'package:spinify/src/model/presence_stats.dart';
import 'package:spinify/src/model/refresh_result.dart';
import 'package:spinify/src/model/stream_position.dart';
import 'package:spinify/src/subscription/server_subscription_manager.dart';
import 'package:spinify/src/subscription/subcibed_on_channel.dart';
import 'package:spinify/src/subscription/subscription_config.dart';
import 'package:spinify/src/util/notifier.dart';
import 'package:ws/ws.dart';

/// Class responsible for sending and receiving data from the server.
/// {@nodoc}
@internal
abstract interface class ISpinifyTransport {
  /// Current state
  /// {@nodoc}
  SpinifyState get state;

  /// State observable.
  /// {@nodoc}
  abstract final SpinifyListenable<SpinifyState> states;

  /// Spinify events.
  /// {@nodoc}
  abstract final SpinifyListenable<SpinifyEvent> events;

  /// Get web socket metrics.
  /// {@nodoc}
  WebSocketMetrics get metrics;

  /// Message response timeout in milliseconds.
  /// {@nodoc}
  ({int min, int avg, int max}) get speed;

  /// Connect to the server.
  /// [url] is a URL of endpoint.
  /// [subs] is a list of server-side subscriptions to subscribe on connect.
  /// {@nodoc}
  Future<void> connect(
    String url,
    ServerSubscriptionManager serverSubscriptionManager,
  );

  /// Send asynchronous message to a server. This method makes sense
  /// only when using Centrifuge library for Go on a server side. In Centrifuge
  /// asynchronous message handler does not exist.
  /// {@nodoc}
  Future<void> sendAsyncMessage(List<int> data);

  /// Subscribe on channel with optional [since] position.
  /// {@nodoc}
  Future<SubcibedOnChannel> subscribe(
    String channel,
    SpinifySubscriptionConfig config,
    SpinifyStreamPosition? since,
  );

  /// Unsubscribe from channel.
  /// {@nodoc}
  Future<void> unsubscribe(
    String channel,
    SpinifySubscriptionConfig config,
  );

  /// Publish data to channel.
  /// {@nodoc}
  Future<void> publish(String channel, List<int> data);

  /// Fetch publication history inside a channel.
  /// Only for channels where history is enabled.
  /// {@nodoc}
  Future<SpinifyHistory> history(
    String channel, {
    int? limit,
    SpinifyStreamPosition? since,
    bool? reverse,
  });

  /// Fetch presence information inside a channel.
  /// {@nodoc}
  Future<SpinifyPresence> presence(String channel);

  /// Fetch presence stats information inside a channel.
  /// {@nodoc}
  Future<SpinifyPresenceStats> presenceStats(String channel);

  /// Disconnect from the server.
  /// e.g. code: 0, reason: 'disconnect called'
  /// {@nodoc}
  Future<void> disconnect(int code, String reason);

  /// Send refresh token command to server.
  /// {@nodoc}
  Future<SpinifyRefreshResult> sendRefresh(String token);

  /// Send subscription channel refresh token command to server.
  /// {@nodoc}
  Future<SpinifySubRefreshResult> sendSubRefresh(
    String channel,
    String token,
  );

  /// Send arbitrary RPC and wait for response.
  Future<List<int>> rpc(String method, List<int> data);

  /// Permanent close connection to the server and
  /// free all allocated resources.
  /// {@nodoc}
  Future<void> close();
}
