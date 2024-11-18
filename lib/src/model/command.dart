import 'package:fixnum/fixnum.dart';
import 'package:meta/meta.dart';

import 'stream_position.dart';

/// {@template command}
/// Command sent from a client to a server.
///
/// Server will
/// only take the first non-null request out of these and may return an error
/// if client passed more than one request.
/// {@category Command}
/// {@endtemplate}
@immutable
sealed class SpinifyCommand implements Comparable<SpinifyCommand> {
  /// {@macro command}
  const SpinifyCommand({
    required this.id,
    required this.timestamp,
  });

  /// ID of command to let client match replies to commands.
  final int id;

  /// Command type.
  abstract final String type;

  /// Check if command has ID.
  abstract final bool hasId;

  /// Timestamp of command.
  final DateTime timestamp;

  @override
  int compareTo(SpinifyCommand other) =>
      switch (timestamp.compareTo(other.timestamp)) {
        0 => id.compareTo(other.id),
        int result => result,
      };

  @override
  int get hashCode => id ^ type.hashCode ^ timestamp.microsecondsSinceEpoch;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpinifyCommand &&
          id == other.id &&
          type == other.type &&
          timestamp == other.timestamp;

  @override
  String toString() => '$type{id: $id}';
}

/// {@macro command}
final class SpinifyConnectRequest extends SpinifyCommand {
  /// {@macro command}
  const SpinifyConnectRequest({
    required super.id,
    required super.timestamp,
    required this.token,
    required this.data,
    required this.subs,
    required this.name,
    required this.version,
  });

  @override
  String get type => 'ConnectRequest';

  @override
  bool get hasId => true;

  /// Token to authenticate.
  final String? token;

  /// Data to send.
  final List<int>? data;

  /// Subscriptions to subscribe.
  final Map<String, SpinifySubscribeRequest>? subs;

  /// Name of client.
  final String name;

  /// Version of client.
  final String version;
}

/// {@macro command}
final class SpinifySubscribeRequest extends SpinifyCommand {
  /// {@macro command}
  const SpinifySubscribeRequest({
    required super.id,
    required super.timestamp,
    required this.channel,
    required this.token,
    required this.recover,
    required this.epoch,
    required this.offset,
    required this.data,
    required this.positioned,
    required this.recoverable,
    required this.joinLeave,
  });

  @override
  String get type => 'SubscribeRequest';

  @override
  bool get hasId => true;

  /// Channel to subscribe.
  final String channel;

  /// Subscription token and callback to get
  /// subscription token upon expiration
  final String? token;

  /// Option to ask server to make subscription recoverable
  final bool? recover;

  /// Epoch to start subscription from
  final String? epoch;

  /// Offset to start subscription from
  final Int64? offset;

  /// Subscription data
  /// (attached to every subscribe/resubscribe request)
  final List<int>? data;

  /// Option to ask server to make subscription positioned
  /// (if not forced by a server)
  final bool? positioned;

  /// Option to ask server to make subscription recoverable
  /// (if not forced by a server)
  final bool? recoverable;

  /// Option to ask server to push Join/Leave messages
  /// (if not forced by a server)
  final bool? joinLeave;
}

/// {@macro command}
final class SpinifyUnsubscribeRequest extends SpinifyCommand {
  /// {@macro command}
  const SpinifyUnsubscribeRequest({
    required super.id,
    required super.timestamp,
    required this.channel,
  });

  @override
  String get type => 'UnsubscribeRequest';

  @override
  bool get hasId => true;

  /// Channel to unsubscribe.
  final String channel;
}

/// {@macro command}
final class SpinifyPublishRequest extends SpinifyCommand {
  /// {@macro command}
  const SpinifyPublishRequest({
    required super.id,
    required super.timestamp,
    required this.channel,
    required this.data,
  });

  @override
  String get type => 'PublishRequest';

  @override
  bool get hasId => true;

  /// Channel to publish.
  final String channel;

  /// Data to publish.
  final List<int> data;
}

/// {@macro command}
final class SpinifyPresenceRequest extends SpinifyCommand {
  /// {@macro command}
  const SpinifyPresenceRequest({
    required super.id,
    required super.timestamp,
    required this.channel,
  });

  @override
  String get type => 'PresenceRequest';

  @override
  bool get hasId => true;

  /// Channel to get presence.
  final String channel;
}

/// {@macro command}
final class SpinifyPresenceStatsRequest extends SpinifyCommand {
  /// {@macro command}
  const SpinifyPresenceStatsRequest({
    required super.id,
    required super.timestamp,
    required this.channel,
  });

  @override
  String get type => 'PresenceStatsRequest';

  @override
  bool get hasId => true;

  /// Channel to get presence stats.
  final String channel;
}

/// {@macro command}
final class SpinifyHistoryRequest extends SpinifyCommand {
  /// {@macro command}
  const SpinifyHistoryRequest({
    required super.id,
    required super.timestamp,
    required this.channel,
    required this.limit,
    required this.since,
    required this.reverse,
  });

  @override
  String get type => 'HistoryRequest';

  @override
  bool get hasId => true;

  /// Channel to get history.
  final String? channel;

  /// Limit of history.
  final int? limit;

  /// Since
  final SpinifyStreamPosition? since;

  /// Reverse
  final bool? reverse;
}

/// {@macro command}
final class SpinifyPingRequest extends SpinifyCommand {
  /// {@macro command}
  const SpinifyPingRequest({
    required super.timestamp,
  }) : super(id: 0);

  @override
  String get type => 'PingRequest';

  @override
  bool get hasId => false;
}

/// {@macro command}
final class SpinifySendRequest extends SpinifyCommand {
  /// {@macro command}
  const SpinifySendRequest({
    required super.timestamp,
    required this.data,
  }) : super(id: 0);

  @override
  String get type => 'SendRequest';

  @override
  bool get hasId => false;

  /// Data to send.
  final List<int> data;
}

/// {@macro command}
final class SpinifyRPCRequest extends SpinifyCommand {
  /// {@macro command}
  const SpinifyRPCRequest({
    required super.id,
    required super.timestamp,
    required this.data,
    required this.method,
  });

  @override
  String get type => 'RPCRequest';

  @override
  bool get hasId => true;

  /// Data to send.
  final List<int> data;

  /// Method to call.
  final String method;
}

/// {@macro command}
final class SpinifyRefreshRequest extends SpinifyCommand {
  /// {@macro command}
  const SpinifyRefreshRequest({
    required super.id,
    required super.timestamp,
    required this.token,
  });

  @override
  String get type => 'RefreshRequest';

  @override
  bool get hasId => true;

  /// Token to refresh.
  /// Token should not be null or empty string.
  final String token;
}

/// {@macro command}
final class SpinifySubRefreshRequest extends SpinifyCommand {
  /// {@macro command}
  const SpinifySubRefreshRequest({
    required super.id,
    required super.timestamp,
    required this.channel,
    required this.token,
  });

  @override
  String get type => 'SubRefreshRequest';

  @override
  bool get hasId => true;

  /// Channel to refresh.
  final String channel;

  /// Token to refresh.
  final String token;
}
