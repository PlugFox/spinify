import 'package:centrifuge_dart/src/model/channel_push.dart';
import 'package:centrifuge_dart/src/model/client_info.dart';
import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:meta/meta.dart';

/// {@template publication}
/// Publication context
/// {@endtemplate}
/// {@category Entity}
@immutable
final class CentrifugePublication extends CentrifugeChannelPush {
  /// {@macro publication}
  const CentrifugePublication({
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
  final CentrifugeClientInfo? info;

  /// Optional tags, this is a map with string keys and string values
  final Map<String, String>? tags;
}
