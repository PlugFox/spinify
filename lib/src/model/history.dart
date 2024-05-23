import 'package:meta/meta.dart';

import 'channel_push.dart';
import 'stream_position.dart';

/// {@template history}
/// History result.
/// {@endtemplate}
/// {@category Reply}
@immutable
final class SpinifyHistory {
  /// {@macro history}
  const SpinifyHistory({
    required this.publications,
    required this.since,
  });

  /// Publications
  final List<SpinifyPublication> publications;

  /// Offset and epoch of last publication in publications list
  final SpinifyStreamPosition since;

  @override
  String toString() => 'SpinifyHistory{}';
}
