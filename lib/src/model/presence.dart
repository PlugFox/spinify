import 'package:meta/meta.dart';
import 'package:spinify/src/model/client_info.dart';

/// {@template presence}
/// Presence
/// {@endtemplate}
/// {@category Entity}
@immutable
final class CentrifugePresence {
  /// {@macro presence}
  const CentrifugePresence({
    required this.channel,
    required this.clients,
  });

  /// Channel
  final String channel;

  /// Publications
  final Map<String, CentrifugeClientInfo> clients;
}
