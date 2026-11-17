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
  // Each search spends the whole default budget, since a round over 6000
  // choices outlasts it, so a few seeds alone hold the suite to its smallest
  // case, and no benchmark runs it over a hundred.
  for (final int seed in [0, 1, 2, 3, 4]) {
    test('A list of a wide range fails and shrinks to 3000 falses within the '
        'default budget, from seed $seed', () async {
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
          (Failed failed) => failed.run.draws.single.value,
          'list',
          List<bool>.filled(3000, false),
        ),
      );
    });
  }
}
