import 'package:spinify/src/model/channel_push.dart';

/// {@template connect}
/// Connect push from Centrifugo server.
/// {@endtemplate}
final class CentrifugeConnect extends CentrifugeChannelPush {
  /// {@macro connect}
  const CentrifugeConnect({
    required super.timestamp,
    required super.channel,
    required this.client,
    required this.version,
    required this.data,
    this.expires,
    this.ttl,
    this.pingInterval,
    this.sendPong,
    this.session,
    this.node,
  });

  @override
  String get type => 'connect';

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
  final List<int> data;
}
