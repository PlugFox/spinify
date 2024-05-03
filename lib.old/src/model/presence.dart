import 'package:meta/meta.dart';

import 'client_info.dart';

/// {@template presence}
/// Presence
/// {@endtemplate}
/// {@category Entity}
@immutable
final class SpinifyPresence {
  /// {@macro presence}
  const SpinifyPresence({
    required this.channel,
    required this.clients,
  });

  /// Channel
  final String channel;

  /// Publications
  final Map<String, SpinifyClientInfo> clients;

  @override
  String toString() => 'SpinifyPresence{channel: $channel}';
}
