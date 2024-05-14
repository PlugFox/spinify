// ignore_for_file: avoid_classes_with_only_static_members

import 'dart:math' as math;

import 'package:meta/meta.dart';

/// Backoff strategy for reconnection.
@internal
abstract final class Backoff {
  /// Randomizer for full jitter technique.
  static final math.Random _rnd = math.Random();

  /// Full jitter technique.
  /// https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/
  static Duration nextDelay(int step, int minDelay, int maxDelay) {
    if (minDelay >= maxDelay) return Duration(milliseconds: maxDelay);
    final val = math.min(maxDelay, minDelay * math.pow(2, step.clamp(0, 31)));
    final interval = _rnd.nextInt(val.toInt());
    return Duration(milliseconds: math.min(maxDelay, minDelay + interval));
  }
}
