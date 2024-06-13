import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:meta/meta.dart';

import 'client_info.dart';
import 'stream_position.dart';

/// {@template spinify_channel_push}
/// Base class for all channel push events.
/// {@endtemplate}
/// {@category Reply}
/// {@subCategory Channel}
/// {@subCategory Push}
@immutable
sealed class SpinifyChannelEvent implements Comparable<SpinifyChannelEvent> {
  /// {@macro spinify_channel_push}
  const SpinifyChannelEvent({
    required this.timestamp,
    required this.channel,
  });

  /// Timestamp
  final DateTime timestamp;

  /// Channel
  final String channel;

  /// Push type.
  abstract final String type;

  /// Map this event to a value of type [T].
  T map<T>({
    required T Function(SpinifyPublication event) publication,
    required T Function(SpinifyPresence event) presence,
    required T Function(SpinifyUnsubscribe event) unsubscribe,
    required T Function(SpinifyMessage event) message,
    required T Function(SpinifySubscribe event) subscribe,
    required T Function(SpinifyConnect event) connect,
    required T Function(SpinifyDisconnect event) disconnect,
    required T Function(SpinifyRefresh event) refresh,
  }) =>
      switch (this) {
        SpinifyPublication event => publication(event),
        SpinifyPresence event => presence(event),
        SpinifyUnsubscribe event => unsubscribe(event),
        SpinifyMessage event => message(event),
        SpinifySubscribe event => subscribe(event),
        SpinifyConnect event => connect(event),
        SpinifyDisconnect event => disconnect(event),
        SpinifyRefresh event => refresh(event),
      };

  /// Map this event to a value of type [T].
  T maybeMap<T>({
    required T Function(SpinifyChannelEvent event) orElse,
    T Function(SpinifyPublication event)? publication,
    T Function(SpinifyPresence event)? presence,
    T Function(SpinifyUnsubscribe event)? unsubscribe,
    T Function(SpinifyMessage event)? message,
    T Function(SpinifySubscribe event)? subscribe,
    T Function(SpinifyConnect event)? connect,
    T Function(SpinifyDisconnect event)? disconnect,
    T Function(SpinifyRefresh event)? refresh,
  }) =>
      map<T>(
        publication: (event) => publication?.call(event) ?? orElse(event),
        presence: (event) => presence?.call(event) ?? orElse(event),
        unsubscribe: (event) => unsubscribe?.call(event) ?? orElse(event),
        message: (event) => message?.call(event) ?? orElse(event),
        subscribe: (event) => subscribe?.call(event) ?? orElse(event),
        connect: (event) => connect?.call(event) ?? orElse(event),
        disconnect: (event) => disconnect?.call(event) ?? orElse(event),
        refresh: (event) => refresh?.call(event) ?? orElse(event),
      );

  /// Map this event to a value of type [T] or return `null`.
  T? mapOrNull<T>({
    T Function(SpinifyPublication event)? publication,
    T Function(SpinifyPresence event)? presence,
    T Function(SpinifyUnsubscribe event)? unsubscribe,
    T Function(SpinifyMessage event)? message,
    T Function(SpinifySubscribe event)? subscribe,
    T Function(SpinifyConnect event)? connect,
    T Function(SpinifyDisconnect event)? disconnect,
    T Function(SpinifyRefresh event)? refresh,
  }) =>
      maybeMap<T?>(
        orElse: (event) => null,
        publication: publication,
        presence: presence,
        unsubscribe: unsubscribe,
        message: message,
        subscribe: subscribe,
        connect: connect,
        disconnect: disconnect,
        refresh: refresh,
      );

  /// Whether this is a publication event
  abstract final bool isPublication;

  /// Whether this is a presence event
  abstract final bool isPresence;

  /// Whether this is an unsubscribe event
  abstract final bool isUnsubscribe;

  /// Whether this is a message event
  abstract final bool isMessage;

  /// Whether this is a subscribe event
  abstract final bool isSubscribe;

  /// Whether this is a connect event
  abstract final bool isConnect;

  /// Whether this is a disconnect event
  abstract final bool isDisconnect;

  /// Whether this is a refresh event
  abstract final bool isRefresh;

  @override
  int compareTo(SpinifyChannelEvent other) =>
      timestamp.compareTo(other.timestamp);

  @override
  String toString() => '$type{channel: $channel}';
}

/// {@template publication}
/// Publication context
/// {@endtemplate}
/// {@category Reply}
/// {@subCategory Channel}
/// {@subCategory Push}
final class SpinifyPublication extends SpinifyChannelEvent {
  /// {@macro publication}
  const SpinifyPublication({
    required super.timestamp,
    required super.channel,
    required this.data,
    required this.offset,
    required this.info,
    required this.tags,
  });

  @override
  String get type => 'Publication';

  /// Publication payload
  final List<int> data;

  /// Optional offset inside history stream, this is an incremental number
  final fixnum.Int64? offset;

  /// Optional information about client connection who published this
  /// (only exists if publication comes from client-side publish() API).
  final SpinifyClientInfo? info;

  /// Optional tags, this is a map with string keys and string values
  final Map<String, String>? tags;

  /// Copy this publication with a new channel.
  SpinifyPublication copyWith({required String channel}) =>
      channel == this.channel
          ? this
          : SpinifyPublication(
              timestamp: timestamp,
              channel: channel,
              data: data,
              offset: offset,
              info: info,
              tags: tags,
            );

  @override
  bool get isConnect => false;

  @override
  bool get isDisconnect => false;

  @override
  bool get isMessage => false;

  @override
  bool get isPresence => false;

  @override
  bool get isPublication => true;

  @override
  bool get isRefresh => false;

  @override
  bool get isSubscribe => false;

  @override
  bool get isUnsubscribe => false;
}

/// {@template channel_presence}
/// Channel presence.
/// Join / Leave events.
/// {@endtemplate}
/// {@category Reply}
/// {@subCategory Channel}
/// {@subCategory Push}
/// {@subCategory Presence}
sealed class SpinifyPresence extends SpinifyChannelEvent {
  /// {@macro channel_presence}
  const SpinifyPresence({
    required super.timestamp,
    required super.channel,
    required this.info,
  });

  /// Join event
  /// {@macro channel_presence}
  const factory SpinifyPresence.join({
    required DateTime timestamp,
    required String channel,
    required SpinifyClientInfo info,
  }) = SpinifyJoin;

  /// Leave event
  /// {@macro channel_presence}
  const factory SpinifyPresence.leave({
    required DateTime timestamp,
    required String channel,
    required SpinifyClientInfo info,
  }) = SpinifyLeave;

  /// Client info
  final SpinifyClientInfo info;

  /// Whether this is a join event
  abstract final bool isJoin;

  /// Whether this is a leave event
  abstract final bool isLeave;

  /// Publications
  //abstract final Map<String, SpinifyClientInfo> clients;

  @override
  bool get isConnect => false;

  @override
  bool get isDisconnect => false;

  @override
  bool get isMessage => false;

  @override
  bool get isPresence => true;

  @override
  bool get isPublication => false;

  @override
  bool get isRefresh => false;

  @override
  bool get isSubscribe => false;

  @override
  bool get isUnsubscribe => false;
}

/// Join event
/// {@macro channel_presence}
/// {@category Reply}
/// {@subCategory Channel}
/// {@subCategory Push}
/// {@subCategory Presence}
final class SpinifyJoin extends SpinifyPresence {
  /// {@macro channel_presence}
  const SpinifyJoin({
    required super.timestamp,
    required super.channel,
    required super.info,
  });

  @override
  String get type => 'Join';

  @override
  bool get isJoin => true;

  @override
  bool get isLeave => false;
}

/// Leave event
/// {@macro channel_presence}
/// {@category Reply}
/// {@subCategory Channel}
/// {@subCategory Push}
/// {@subCategory Presence}
final class SpinifyLeave extends SpinifyPresence {
  /// {@macro channel_presence}
  const SpinifyLeave({
    required super.timestamp,
    required super.channel,
    required super.info,
  });

  @override
  String get type => 'Leave';

  @override
  bool get isJoin => false;

  @override
  bool get isLeave => true;
}

/// {@template unsubscribe}
/// Unsubscribe push from Centrifugo server.
/// {@endtemplate}
/// {@category Reply}
/// {@subCategory Channel}
/// {@subCategory Push}
final class SpinifyUnsubscribe extends SpinifyChannelEvent {
  /// {@macro unsubscribe}
  const SpinifyUnsubscribe({
    required super.timestamp,
    required super.channel,
    required this.code,
    required this.reason,
  });

  @override
  String get type => 'Unsubscribe';

  /// Code of unsubscribe.
  final int code;

  /// Reason of unsubscribe.
  final String reason;

  @override
  bool get isConnect => false;

  @override
  bool get isDisconnect => false;

  @override
  bool get isMessage => false;

  @override
  bool get isPresence => false;

  @override
  bool get isPublication => false;

  @override
  bool get isRefresh => false;

  @override
  bool get isSubscribe => false;

  @override
  bool get isUnsubscribe => true;
}

/// {@template message}
/// Message push from Centrifugo server.
/// {@endtemplate}
/// {@category Reply}
/// {@subCategory Channel}
/// {@subCategory Push}
final class SpinifyMessage extends SpinifyChannelEvent {
  /// {@macro message}
  const SpinifyMessage({
    required super.timestamp,
    required super.channel,
    required this.data,
  });

  @override
  String get type => 'Message';

  /// Payload of message.
  final List<int> data;

  @override
  bool get isConnect => false;

  @override
  bool get isDisconnect => false;

  @override
  bool get isMessage => true;

  @override
  bool get isPresence => false;

  @override
  bool get isPublication => false;

  @override
  bool get isRefresh => false;

  @override
  bool get isSubscribe => false;

  @override
  bool get isUnsubscribe => false;
}

/// {@template subscribe}
/// Subscribe push from Centrifugo server.
/// {@endtemplate}
/// {@category Reply}
/// {@subCategory Channel}
/// {@subCategory Push}
final class SpinifySubscribe extends SpinifyChannelEvent {
  /// {@macro subscribe}
  const SpinifySubscribe({
    required super.timestamp,
    required super.channel,
    required this.recoverable,
    required this.positioned,
    required this.since,
    required this.data,
  });

  @override
  String get type => 'Subscribe';

  /// Whether subscription is recoverable.
  final bool recoverable;

  /// Data attached to subscription.
  final SpinifyStreamPosition since;

  /// Whether subscription is positioned.
  final bool positioned;

  /// Data attached to subscription.
  final List<int>? data;

  @override
  bool get isConnect => false;

  @override
  bool get isDisconnect => false;

  @override
  bool get isMessage => false;

  @override
  bool get isPresence => false;

  @override
  bool get isPublication => false;

  @override
  bool get isRefresh => false;

  @override
  bool get isSubscribe => true;

  @override
  bool get isUnsubscribe => false;
}

/// {@template connect}
/// Connect push from Centrifugo server.
/// {@endtemplate}
/// {@category Reply}
/// {@subCategory Channel}
/// {@subCategory Push}
final class SpinifyConnect extends SpinifyChannelEvent {
  /// {@macro connect}
  const SpinifyConnect({
    required super.timestamp,
    required super.channel,
    required this.client,
    required this.version,
    required this.data,
    required this.expires,
    required this.ttl,
    required this.pingInterval,
    required this.sendPong,
    required this.session,
    required this.node,
  });

  @override
  String get type => 'Connect';

  /// Unique client connection ID server issued to this connection
  final String client;

  /// Server version
  final String version;

  /// Whether a server will expire connection at some point
  final bool? expires;

  /// Time when connection will be expired
  final DateTime? ttl;

  /// Client must periodically (once in 25 secs, configurable) send
  /// ping messages to server. If pong has not beed received in 5 secs
  /// (configurable) then client must disconnect from server
  /// and try to reconnect with backoff strategy.
  final Duration? pingInterval;

  /// Whether to send asynchronous message when pong received.
  final bool? sendPong;

  /// Session ID.
  final String? session;

  /// Server node ID.
  final String? node;

  /// Payload of connected push.
  final List<int>? data;

  @override
  bool get isConnect => true;

  @override
  bool get isDisconnect => false;

  @override
  bool get isMessage => false;

  @override
  bool get isPresence => false;

  @override
  bool get isPublication => false;

  @override
  bool get isRefresh => false;

  @override
  bool get isSubscribe => false;

  @override
  bool get isUnsubscribe => false;
}

/// {@template disconnect}
/// Disconnect push from Centrifugo server.
/// {@endtemplate}
/// {@category Reply}
/// {@subCategory Channel}
/// {@subCategory Push}
final class SpinifyDisconnect extends SpinifyChannelEvent {
  /// {@macro disconnect}
  const SpinifyDisconnect({
    required super.timestamp,
    required super.channel,
    required this.code,
    required this.reason,
    required this.reconnect,
  });

  @override
  String get type => 'Disconnect';

  /// Code of disconnect.
  /// Codes have some rules which should be followed by a client
  /// connector implementation.
  /// These rules described below.
  ///
  /// Codes in range 0-2999 should not be used by a Centrifuge library user.
  /// Those are reserved for the client-side and transport specific needs.
  /// Codes in range >=5000 should not be used also.
  /// Those are reserved by Centrifuge.
  ///
  /// Client should reconnect upon receiving code in range
  /// 3000-3499, 4000-4499, >=5000.
  /// For codes <3000 reconnect behavior can be adjusted for specific transport.
  ///
  /// Codes in range 3500-3999 and 4500-4999 are application terminal codes,
  /// no automatic reconnect should be made by a client implementation.
  ///
  /// Library users supposed to use codes in range 4000-4999 for creating custom
  /// disconnects.
  final int code;

  /// Reason of disconnect.
  final String reason;

  /// Reconnect flag.
  final bool reconnect;

  @override
  bool get isConnect => false;

  @override
  bool get isDisconnect => true;

  @override
  bool get isMessage => false;

  @override
  bool get isPresence => false;

  @override
  bool get isPublication => false;

  @override
  bool get isRefresh => false;

  @override
  bool get isSubscribe => false;

  @override
  bool get isUnsubscribe => false;
}

/// {@template refresh}
/// Refresh push from Centrifugo server.
/// {@endtemplate}
/// {@category Reply}
/// {@subCategory Channel}
/// {@subCategory Push}
final class SpinifyRefresh extends SpinifyChannelEvent {
  /// {@macro refresh}
  const SpinifyRefresh({
    required super.timestamp,
    required super.channel,
    required this.expires,
    required this.ttl,
  });

  @override
  String get type => 'Refresh';

  /// Whether a server will expire connection at some point
  final bool expires;

  /// Time when connection will be expired
  final DateTime? ttl;

  @override
  bool get isConnect => false;

  @override
  bool get isDisconnect => false;

  @override
  bool get isMessage => false;

  @override
  bool get isPresence => false;

  @override
  bool get isPublication => false;

  @override
  bool get isRefresh => true;

  @override
  bool get isSubscribe => false;

  @override
  bool get isUnsubscribe => false;
}
