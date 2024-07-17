import 'package:spinify/spinify.dart';
import 'package:test/test.dart';

void main() {
  group('Logs', () {
    void Function({
      SpinifyLogLevel level,
      String event,
      String message,
      Map<String, Object?> context,
    }) addFakeTo(SpinifyLogBuffer buffer) => (
            {level = const SpinifyLogLevel.debug(),
            event = 'fake',
            message = 'Fake',
            context = const <String, Object?>{}}) =>
        buffer.add(level, event, message, context);

    test('LogBuffer', () async {
      final buffer = SpinifyLogBuffer(size: 10);
      expect(buffer.logs, isEmpty);
      expect(buffer.size, 10);
      expect(buffer.isFull, isFalse);
      expect(buffer.isEmpty, isTrue);
      final addFake = addFakeTo(buffer);
      addFake();
      expect(buffer.logs, hasLength(1));
      expect(buffer.isFull, isFalse);
      expect(buffer.isEmpty, isFalse);
      buffer.clear();
      expect(buffer.logs, isEmpty);
      expect(buffer.isFull, isFalse);
      expect(buffer.isEmpty, isTrue);
      for (var i = 0; i < buffer.size; i++) {
        addFake();
      }
      expect(buffer.logs, hasLength(buffer.size));
      expect(buffer.isFull, isTrue);
      expect(buffer.isEmpty, isFalse);
      addFake();
      expect(buffer.logs, hasLength(buffer.size));
      expect(buffer.isFull, isTrue);
      expect(buffer.isEmpty, isFalse);
    });
  });
}
