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

/// Class responsible for sending and receiving data from the server.
@internal
abstract interface class ISpinifyTransport {
  /// Current state
  SpinifyState get state;

  /// State observable.
  abstract final SpinifyListenable<SpinifyState> states;

  /// Spinify events.
  abstract final SpinifyListenable<SpinifyEvent> events;

  /// Received bytes count & size.
  ({BigInt count, BigInt size}) get received;

  /// Transferred bytes count & size.
  ({BigInt count, BigInt size}) get transferred;

  /// Message response timeout in milliseconds.
  ({int min, int avg, int max}) get speed;

  /// Connect to the server.
  /// [url] is a URL of endpoint.
  /// [subs] is a list of server-side subscriptions to subscribe on connect.
  Future<void> connect(
    String url,
    ServerSubscriptionManager serverSubscriptionManager,
  );

  /// Send asynchronous message to a server. This method makes sense
  /// only when using Centrifuge library for Go on a server side. In Centrifuge
  /// asynchronous message handler does not exist.
  Future<void> sendAsyncMessage(List<int> data);

  /// Subscribe on channel with optional [since] position.
  Future<SubcibedOnChannel> subscribe(
    String channel,
    SpinifySubscriptionConfig config,
    SpinifyStreamPosition? since,
  );

  /// Unsubscribe from channel.
  Future<void> unsubscribe(
    String channel,
    SpinifySubscriptionConfig config,
  );

  /// Publish data to channel.
  Future<void> publish(String channel, List<int> data);

  /// Fetch publication history inside a channel.
  /// Only for channels where history is enabled.
  Future<SpinifyHistory> history(
    String channel, {
    int? limit,
    SpinifyStreamPosition? since,
    bool? reverse,
  });

  /// Fetch presence information inside a channel.
  Future<SpinifyPresence> presence(String channel);

  /// Fetch presence stats information inside a channel.
  Future<SpinifyPresenceStats> presenceStats(String channel);

  /// Disconnect from the server.
  /// e.g. code: 0, reason: 'disconnect called'
  Future<void> disconnect(int code, String reason);

  /// Send refresh token command to server.
  Future<SpinifyRefreshResult> sendRefresh(String token);

  /// Send subscription channel refresh token command to server.
  Future<SpinifySubRefreshResult> sendSubRefresh(
    String channel,
    String token,
  );

  /// Send arbitrary RPC and wait for response.
  Future<List<int>> rpc(String method, List<int> data);

  /// Permanent close connection to the server and
  /// free all allocated resources.
  Future<void> close();
}
