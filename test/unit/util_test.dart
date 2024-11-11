import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:spinify/src/util/backoff.dart';
import 'package:spinify/src/util/event_queue.dart';
import 'package:spinify/src/util/guarded.dart';
import 'package:spinify/src/util/list_equals.dart';
import 'package:spinify/src/util/map_equals.dart';
import 'package:spinify/src/util/mutex.dart';
import 'package:test/test.dart';

void main() => group('Util', () {
      test('Backoff', () {
        expect(() => Backoff.nextDelay(5, 10, 50), returnsNormally);
        expect(Backoff.nextDelay(5, 10, 50), isA<Duration>());
        expect(Backoff.nextDelay(5, 5, 5), isA<Duration>());
      });

      test(
        'EventQueue',
        () => fakeAsync(
          (async) {
            expect(EventQueue.new, returnsNormally);
            var queue = EventQueue();
            expect(queue.isClosed, isFalse);
            expectLater(queue.add(() {}), completes);
            var counter = 0;
            expectLater(queue.add(() => counter++), completes);
            expect(counter, 0);
            expectLater(queue.close(), completes);
            async.elapse(Duration.zero);
            expect(counter, 1);
            expect(queue.isClosed, isTrue);

            queue = EventQueue();
            expectLater(queue.add(() {}), completes);
            expectLater(queue.add(() {}), throwsStateError);
            expectLater(queue.close(force: true), completes);
            expectLater(queue.close(force: true), completes);
            expectLater(queue.close(force: false), completes);
            async.elapse(Duration.zero);
            expect(queue.isClosed, isTrue);
            expectLater(() => queue.add(() {}), throwsStateError);
          },
        ),
      );

      test('Guarded', () {
        expect(
          () => guarded(() => 1),
          returnsNormally,
        );
        expect(
          () => guarded(() => throw Exception(), ignore: false),
          throwsException,
        );
        expect(
          () => guarded(() => throw Exception(), ignore: true),
          returnsNormally,
        );
        expect(
          () => guarded(
            () => Future.delayed(
              Duration.zero,
              () {
                throw Exception();
              },
            ),
            ignore: false,
          ),
          returnsNormally,
        );
        expect(
          () => guarded(
            () => Future.delayed(
              Duration.zero,
              () {
                throw Exception();
              },
            ),
            ignore: true,
          ),
          returnsNormally,
        );

        expect(
          () => guarded(() {
            Completer<void>().completeError(Exception());
          }),
          returnsNormally,
        );
      });

      test('AsyncGuarded', () {
        expectLater(
          asyncGuarded(() async => 1),
          completes,
        );
        expectLater(
          asyncGuarded(() async => throw Exception(), ignore: false),
          throwsException,
        );
        expectLater(
          asyncGuarded(() async => throw Exception(), ignore: true),
          completes,
        );
        expectLater(
          asyncGuarded(() async {
            Completer<void>().completeError(Exception());
          }),
          throwsException,
        );
        expectLater(
          asyncGuarded(() async {
            await Future<void>.delayed(Duration.zero);
            Completer<void>().completeError(Exception());
          }),
          completes,
        );
      });

      test('ListEquals', () {
        expect(listEquals([1, 2, 3], [1, 2, 3]), isTrue);
        expect(listEquals([1, 2, 3], [1, 2, 4]), isFalse);
        expect(listEquals([1, 2, 3], [1, 2]), isFalse);
        expect(listEquals(null, [1, 2, 3, 4]), isFalse);
        expect(listEquals([1, 2, 3, 4], null), isFalse);
        expect(listEquals<void>(null, null), isTrue);
      });

      test('MapEquals', () {
        expect(mapEquals({1: 2, 3: 4}, {1: 2, 3: 4}), isTrue);
        expect(mapEquals({1: 2, 3: 4}, {1: 2, 3: 5}), isFalse);
        expect(mapEquals({1: 2, 3: 4}, {1: 2}), isFalse);
        expect(mapEquals(null, {1: 2, 3: 4}), isFalse);
        expect(mapEquals({1: 2, 3: 4}, null), isFalse);
        expect(mapEquals<void, void>(null, null), isTrue);
      });

      test('Mutex', () async {
        {
          final m = MutexDisabled();
          expect(m.locks, equals(0));
          expect(m.pending, isEmpty);
          unawaited(
            expectLater(
              m.protect(() => Future.value(1)),
              completion(equals(1)),
            ),
          );
          expect(m.locks, equals(0));
          expect(m.pending, isEmpty);
          unawaited(
            expectLater(
              m.lock(),
              completes,
            ),
          );
          expect(m.locks, equals(0));
          expect(m.pending, isEmpty);
          expect(
            m.unlock,
            returnsNormally,
          );
          unawaited(
            expectLater(
              m.wait(),
              completes,
            ),
          );
        }

        fakeAsync((async) {
          final m = MutexImpl();
          expect(m.locks, equals(0));
          expect(m.pending, isEmpty);
          unawaited(
            expectLater(
              m.lock(),
              completes,
            ),
          );
          expect(m.locks, equals(1));
          expect(m.pending, isNotEmpty);
          unawaited(
            expectLater(
              m.lock(),
              completes,
            ),
          );
          expect(m.locks, equals(2));
          unawaited(
            expectLater(
              m.wait(),
              completes,
            ),
          );
          expect(m.pending, hasLength(2));
          expect(m.unlock, returnsNormally);
          expect(m.locks, equals(1));
          expect(m.pending, hasLength(1));
          expect(m.unlock, returnsNormally);
          expect(m.locks, equals(0));
          expect(m.pending, isEmpty);
          unawaited(
            expectLater(
              m.wait(),
              completes,
            ),
          );

          unawaited(
            expectLater(
              m.protect(
                () => Future.delayed(const Duration(hours: 1), () => 1),
              ),
              completion(equals(1)),
            ),
          );
          async.flushMicrotasks();
          expect(m.locks, equals(1));
          async.flushTimers();
          expect(m.locks, equals(0));
        });

        fakeAsync((async) {
          final m = MutexImpl();
          final list = <int>[for (var i = 0; i < 10; i++) i];
          final result = <int>[];
          final copy = list.toList();
          for (var i = 0; i < list.length; i++) {
            unawaited(
              expectLater(
                m.protect(() async {
                  final value = copy.removeAt(0);
                  await Future<void>.delayed(
                    Duration(seconds: list.length - i),
                  );
                  result.add(value);
                }),
                completes,
              ),
            );
          }
          async.flushMicrotasks();
          expect(m.locks, equals(list.length));
          expect(m.pending, hasLength(list.length));
          async.elapse(const Duration(seconds: 10));
          expect(m.locks, equals(list.length - 1));
          expect(m.pending, hasLength(list.length - 1));
          async.flushTimers();
          expect(listEquals(result, list), isTrue);
          expect(m.locks, equals(0));
          expect(m.pending, isEmpty);
        });

        fakeAsync((async) {
          final m = MutexImpl();
          final list = <int>[for (var i = 0; i < 10; i++) i];
          final result = <int>[];
          final copy = list.toList();
          for (var i = 0; i < list.length; i++) {
            m.lock();
            final value = copy.removeAt(0);
            Future<void>.delayed(Duration(seconds: list.length - i), m.unlock);
            result.add(value);
          }
          expect(m.locks, equals(list.length));
          expect(m.pending, hasLength(list.length));
          async.flushTimers();
          expect(m.locks, equals(0));
          expect(m.pending, isEmpty);
          expect(listEquals(result, list), isTrue);
        });
      });
    });
