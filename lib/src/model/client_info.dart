import 'package:meta/meta.dart';

import '../util/list_equals.dart';

/// {@template client_info}
/// Client information.
/// {@endtemplate}
/// {@category Reply}
/// {@subCategory Channel}
@immutable
final class SpinifyClientInfo {
  /// {@macro client_info}
  SpinifyClientInfo({
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
  late final int hashCode = Object.hashAll([
    user,
    client,
    connectionInfo,
    channelInfo,
  ]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpinifyClientInfo &&
          user == other.user &&
          client == other.client &&
          listEquals(connectionInfo, other.connectionInfo) &&
          listEquals(channelInfo, other.channelInfo);

  @override
  String toString() => 'SpinifyClientInfo{'
      'user: $user, '
      'client: $client'
      '}';
}
