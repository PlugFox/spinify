import 'dart:async';

import 'package:meta/meta.dart';
import 'package:spinify/src/client/state.dart';
import 'package:spinify/src/model/event.dart';
import 'package:spinify/src/model/history.dart';
import 'package:spinify/src/model/presence.dart';
import 'package:spinify/src/model/presence_stats.dart';
import 'package:spinify/src/model/refresh.dart';
import 'package:spinify/src/model/stream_position.dart';
import 'package:spinify/src/subscription/server_subscription_manager.dart';
import 'package:spinify/src/subscription/subcibed_on_channel.dart';
import 'package:spinify/src/subscription/subscription_config.dart';
import 'package:spinify/src/util/notifier.dart';

/// Class responsible for sending and receiving data from the server.
/// {@nodoc}
@internal
abstract interface class ISpinifyTransport {
  /// Current state
  /// {@nodoc}
  CentrifugeState get state;

  /// State observable.
  /// {@nodoc}
  abstract final CentrifugeListenable<CentrifugeState> states;

  /// Centrifuge events.
  /// {@nodoc}
  abstract final CentrifugeListenable<CentrifugeEvent> events;

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
    CentrifugeSubscriptionConfig config,
    CentrifugeStreamPosition? since,
  );

  /// Unsubscribe from channel.
  /// {@nodoc}
  Future<void> unsubscribe(
    String channel,
    CentrifugeSubscriptionConfig config,
  );

  /// Publish data to channel.
  /// {@nodoc}
  Future<void> publish(String channel, List<int> data);

  /// Fetch publication history inside a channel.
  /// Only for channels where history is enabled.
  /// {@nodoc}
  Future<CentrifugeHistory> history(
    String channel, {
    int? limit,
    CentrifugeStreamPosition? since,
    bool? reverse,
  });

  /// Fetch presence information inside a channel.
  /// {@nodoc}
  Future<CentrifugePresence> presence(String channel);

  /// Fetch presence stats information inside a channel.
  /// {@nodoc}
  Future<CentrifugePresenceStats> presenceStats(String channel);

  /// Disconnect from the server.
  /// e.g. code: 0, reason: 'disconnect called'
  /// {@nodoc}
  Future<void> disconnect(int code, String reason);

  /// Send refresh token command to server.
  /// {@nodoc}
  Future<CentrifugeRefreshResult> sendRefresh(String token);

  /// Send subscription channel refresh token command to server.
  /// {@nodoc}
  Future<CentrifugeSubRefreshResult> sendSubRefresh(
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
