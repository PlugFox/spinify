import 'package:centrifuge_dart/src/model/channel_push.dart';

/// {@template unsubscribe}
/// Unsubscribe push from Centrifugo server.
/// {@endtemplate}
final class CentrifugeUnsubscribe extends CentrifugeChannelPush {
  /// {@macro unsubscribe}
  const CentrifugeUnsubscribe({
    required super.timestamp,
    required super.channel,
    required this.code,
    required this.reason,
  });

  @override
  String get type => 'unsubscribe';

  /// Code of unsubscribe.
  final int code;

  /// Reason of unsubscribe.
  final String reason;
}
