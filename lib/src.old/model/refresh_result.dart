import 'package:meta/meta.dart';

/// Result of connection refresh
final class SpinifyRefreshResult {
  /// Result of connection refresh
  const SpinifyRefreshResult({
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

/// Result of subscription refresh
@immutable
final class SpinifySubRefreshResult {
  /// Result of connection refresh
  const SpinifySubRefreshResult({
    required this.expires,
    this.ttl,
  });

  /// Whether a server will expire subscription at some point
  final bool expires;

  /// Time when subscription will be expired
  final DateTime? ttl;
}
