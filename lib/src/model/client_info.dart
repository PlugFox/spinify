import 'package:meta/meta.dart';

/// {@template client_info}
/// Client information.
/// {@endtemplate}
/// {@category Entity}
@immutable
final class SpinifyClientInfo {
  /// {@macro client_info}
  const SpinifyClientInfo({
    required this.user,
    required this.client,
    required this.connectionInfo,
    required this.channelInfo,
  });

  /// User
  final String user;

  /// Client
  final String client;

  /// Connection information
  final List<int>? connectionInfo;

  /// Channel information
  final List<int>? channelInfo;

  @override
  int get hashCode => Object.hashAll([
        user,
        client,
        connectionInfo,
        channelInfo,
      ]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpinifyClientInfo &&
          user == other.client &&
          client == other.client &&
          connectionInfo == other.connectionInfo &&
          channelInfo == other.channelInfo;

  @override
  String toString() => 'SpinifyClientInfo{'
      'user: $user, '
      'client: $client, '
      'connectionInfo: ${connectionInfo == null ? 'null' : 'bytes'}, '
      'channelInfo: ${channelInfo == null ? 'null' : 'bytes'}'
      '}';
}
