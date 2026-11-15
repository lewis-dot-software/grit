import 'package:grit/src/choice/choice_source.dart';
import 'package:grit/src/gen/gen.dart';
import 'package:test/test.dart';

import '../support/bottomless.dart';
import '../support/fixed_random.dart';

void main() {
  // This test stands alone in its file, so its draws are the first its
  // isolate makes: a stack runs out inside a write to a record most often
  // before the code making the write is optimised.
  test('After a draw a stack overflow left, each of the run\'s records reads '
      'whole or throws the overflow, never half-written', () {
    for (int run = 0; run < 30; run++) {
      final ChoiceSource source = .random(
        FixedRandom(0.9, ints: const [3]),
        limit: 10,
      );
      final RunDraw draw = .new(source);
      Object? thrown;
      try {
        draw(run.isEven ? overflowing : bottomless);
      } on Object catch (error) {
        thrown = error;
      }
      expect(thrown, isA<StackOverflowError>(), reason: 'run $run');
      final Map<String, Object? Function()> records = {
        'spans': () => draw.spans,
        'draws': () => draw.draws,
        'notes': () => draw.notes,
        'thrown': () => draw.thrown,
        'record': () => source.record,
        'length': () => source.length,
      };
      for (final MapEntry(:String key, :Object? Function() value)
          in records.entries) {
        expect(
          value,
          anyOf(returnsNormally, throwsA(isA<StackOverflowError>())),
          reason: 'the $key of run $run',
        );
      }
    }
  });
}
