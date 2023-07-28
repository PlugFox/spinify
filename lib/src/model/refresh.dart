import 'package:meta/meta.dart';

/// {@nodoc}
@internal
@immutable
final class CentrifugeRefreshResult {
  /// {@nodoc}
  const CentrifugeRefreshResult({
    required this.expires,
    this.client,
    this.version,
    this.ttl,
  });

  /// Unique client connection ID server issued to this connection
  final String? client;

  /// Server version
  final String? version;

  /// Whether a server will expire connection at some point
  final bool expires;

  /// Time when connection will be expired
  final DateTime? ttl;
}

/// {@nodoc}
@internal
@immutable
final class CentrifugeSubRefreshResult {
  /// {@nodoc}
  const CentrifugeSubRefreshResult({
    required this.expires,
    this.ttl,
  });

  /// Whether a server will expire subscription at some point
  final bool expires;

  /// Time when subscription will be expired
  final DateTime? ttl;
}
