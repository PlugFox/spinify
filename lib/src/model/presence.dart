import 'package:centrifuge_dart/src/model/client_info.dart';
import 'package:meta/meta.dart';

/// {@template presence}
/// Presence
/// {@endtemplate}
/// {@category Entity}
@immutable
final class CentrifugePresence {
  /// {@macro presence}
  const CentrifugePresence({
    required this.clients,
  });

  /// Publications
  final Map<String, CentrifugeClientInfo> clients;
}
