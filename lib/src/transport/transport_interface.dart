import 'dart:async';

import 'package:centrifuge_dart/centrifuge.dart';
import 'package:centrifuge_dart/src/model/event.dart';
import 'package:centrifuge_dart/src/model/history.dart';
import 'package:centrifuge_dart/src/model/presence.dart';
import 'package:centrifuge_dart/src/model/presence_stats.dart';
import 'package:centrifuge_dart/src/model/refresh.dart';
import 'package:centrifuge_dart/src/model/stream_position.dart';
import 'package:centrifuge_dart/src/subscription/server_subscription_manager.dart';
import 'package:centrifuge_dart/src/subscription/subcibed_on_channel.dart';
import 'package:centrifuge_dart/src/util/notifier.dart';
import 'package:meta/meta.dart';

/// Class responsible for sending and receiving data from the server.
/// {@nodoc}
@internal
abstract interface class ICentrifugeTransport {
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

  /// Permanent close connection to the server and
  /// free all allocated resources.
  /// {@nodoc}
  Future<void> close();
}
