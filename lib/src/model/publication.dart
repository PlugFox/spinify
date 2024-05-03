import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:meta/meta.dart';
import 'channel_push.dart';
import 'client_info.dart';

/// {@template publication}
/// Publication context
/// {@endtemplate}
/// {@category Event}
/// {@subCategory Push}
@immutable
final class SpinifyPublication extends SpinifyChannelPush {
  /// {@macro publication}
  const SpinifyPublication({
    required super.timestamp,
    required super.channel,
    required this.data,
    this.offset,
    this.info,
    this.tags,
  });

  @override
  String get type => 'publication';

  /// Publication payload
  final List<int> data;

  /// Optional offset inside history stream, this is an incremental number
  final fixnum.Int64? offset;

  /// Optional information about client connection who published this
  /// (only exists if publication comes from client-side publish() API).
  final SpinifyClientInfo? info;

  /// Optional tags, this is a map with string keys and string values
  final Map<String, String>? tags;

  @override
  String toString() => 'SpinifyPublication{channel: $channel}';
}
