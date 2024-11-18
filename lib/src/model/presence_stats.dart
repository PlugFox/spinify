import 'package:meta/meta.dart';

/// {@template presence_stats}
/// Presence stats
/// {@endtemplate}
/// {@category Entity}
@immutable
final class SpinifyPresenceStats {
  /// {@macro presence_stats}
  const SpinifyPresenceStats({
    required this.channel,
    required this.clients,
    required this.users,
  });

  /// Channel
  final String channel;

  /// Clients count
  final int clients;

  /// Users count
  final int users;

  @override
  int get hashCode => Object.hash(
        channel,
        clients,
        users,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpinifyPresenceStats &&
          channel == other.channel &&
          clients == other.clients &&
          users == other.users;

  @override
  String toString() => 'SpinifyPresenceStats{channel: $channel}';
}
