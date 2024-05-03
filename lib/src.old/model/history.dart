import 'package:meta/meta.dart';
import 'package:spinify/src.old/model/publication.dart';
import 'package:spinify/src.old/model/stream_position.dart';

/// {@template history}
/// History
/// {@endtemplate}
/// {@category Entity}
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
