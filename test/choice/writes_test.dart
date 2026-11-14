import 'package:grit/src/choice/writes.dart';
import 'package:test/test.dart';

void main() {
  group('writes', () {
    test('make each write, and throw nothing where none was cut short', () {
      final Writes writes = .new();
      final List<int> kept = [];
      writes(() => kept.add(1));
      writes(() => kept.add(2));
      expect(kept, [1, 2]);
      expect(writes.throwIfCut, returnsNormally);
    });

    test('rethrow the error that cuts a write short, and from then on throw '
        'the first such error, with its stack, on every read', () {
      final Writes writes = .new();
      final StateError first = .new('first');
      final StateError second = .new('second');
      StackTrace? firstStack;
      try {
        writes(() => throw first);
      } on Object catch (error, stackTrace) {
        expect(error, same(first));
        firstStack = stackTrace;
      }
      expect(firstStack, isNotNull, reason: 'the cut write rethrew');
      expect(() => writes(() => throw second), throwsA(same(second)));
      for (int read = 0; read < 2; read++) {
        Object? thrown;
        StackTrace? stack;
        try {
          writes.throwIfCut();
        } on Object catch (error, stackTrace) {
          thrown = error;
          stack = stackTrace;
        }
        expect(thrown, same(first), reason: 'read $read');
        expect('$stack', '$firstStack', reason: 'read $read');
      }
    });
  });
}
