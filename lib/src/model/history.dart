import 'package:meta/meta.dart';

import '../util/list_equals.dart';
import 'channel_event.dart';
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
  int get hashCode => Object.hashAll([
        since.epoch,
        since.offset,
        publications,
      ]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpinifyHistory &&
          since == other.since &&
          listEquals(publications, other.publications);

  @override
  String toString() => 'SpinifyHistory{}';
}
