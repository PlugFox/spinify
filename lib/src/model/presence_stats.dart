import 'package:meta/meta.dart';

/// {@template presence_stats}
/// Presence stats
/// {@endtemplate}
/// {@category Entity}
@immutable
final class CentrifugePresenceStats {
  /// {@macro presence_stats}
  const CentrifugePresenceStats({
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
}
