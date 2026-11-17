import 'package:grit/grit.dart';
import 'package:grit/src/api/property_run.dart';
import 'package:test/test.dart';

import '../support/fake_clock.dart';
import '../support/memory_store.dart';

/// A list from 1001 to 3999 long of booleans, under the false property that
/// every list is shorter than 3000.
void _shorterThan3000(Draw draw) {
  final List<bool> list = draw(
    .list(.boolean(), minLength: 1001, maxLength: 3999),
  );
  expect(list.length, lessThan(3000));
}

void main() {
  // The default budget runs out before every element shrinks to false, so
  // the length alone is held to its smallest failing one, within a few.
  for (final int seed in [0, 1]) {
    test('A list of a wide range fails and its length shrinks to within 5 '
        'of the smallest that fails, from seed $seed', () async {
      final Outcome outcome = await PropertyRun(
        .new(),
        callSite: .of(.current),
        clock: FakeClock(),
        store: MemoryStore(),
        seed: seed,
      ).outcome(_shorterThan3000);
      expect(
        outcome,
        isA<Failed>().having(
          (Failed failed) =>
              (failed.run.draws.single.value as List<bool>).length,
          'length',
          inInclusiveRange(3000, 3005),
        ),
      );
    });
  }
}
