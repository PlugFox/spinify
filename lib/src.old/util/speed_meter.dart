import 'dart:math' as math;

/// Speed meter
class SpinifySpeedMeter {
  /// Speed meter
  SpinifySpeedMeter(this.size) : _speeds = List.filled(size, 0);

  /// Size of the speed meter
  final int size;
  final List<int> _speeds;
  int _pointer = 0;
  int _count = 0;

  /// Add new speed in ms
  void add(num speed) {
    _speeds[_pointer] = speed.toInt();
    _pointer = (_pointer + 1) % size;
    if (_count < size) _count++;
  }

  /// Get speed in ms
  ({int min, int avg, int max}) get speed {
    if (_count == 0) return (min: 0, avg: 0, max: 0);
    var sum = _speeds.first, min = sum, max = sum;
    for (final value in _speeds) {
      min = math.min<int>(min, value);
      max = math.max<int>(max, value);
      sum += value;
    }
    return (min: min, avg: sum ~/ _count, max: max);
  }
}
