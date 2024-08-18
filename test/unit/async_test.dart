import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:test/test.dart';

Timer? _$cacheTimer;
Map<int, Uint8List> _$cache = () {
  final cache = <int, Uint8List>{};
  return cache;
}();

Uint8List _cached(int key, Uint8List Function() create) =>
    _$cache.putIfAbsent(key, () {
      _$cacheTimer ??= Timer(const Duration(minutes: 5), () {
        _$cacheTimer = null;
        _$cache.clear();
      });
      return create();
    });

void main() => group('Async test', () {
      test(
        'Async cache',
        () => fakeAsync(
          (async) {
            expect(_$cache, isEmpty);
            expect(_$cacheTimer, isNull);
            final value = _cached(1, () => Uint8List.fromList([1, 2, 3]));
            expect(value, equals([1, 2, 3]));
            expect(_$cache, isNotEmpty);
            expect(_$cacheTimer, isNotNull);
            async.elapse(const Duration(minutes: 2));
            expect(_$cache, isNotEmpty);
            expect(_$cacheTimer, isNotNull);
            expect(_cached(1, () => Uint8List.fromList([])), same(value));
            async.elapse(const Duration(minutes: 3));
            expect(_$cache, isEmpty);
            expect(_$cacheTimer, isNull);
            expect(
                _cached(1, () => Uint8List.fromList([])), isNot(same(value)));
          },
        ),
      );
    });
