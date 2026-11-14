import 'package:grit/grit.dart';
import 'package:grit/src/api/property_run.dart';
import 'package:test/test.dart';

import 'fake_clock.dart';

/// The seeds every challenge is searched from.
const List<int> everySeed = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];

/// Declares a test for each of [everySeed] that the search of [body] from it,
/// under the default settings, fails, and shrinks to the draws [smallest]
/// holds, in order, where [shrinks] holds the seed.
///
/// The search is timed by a clock that never moves, so shrinking ends on its
/// own end or its step budget alone, and a fall in shrink quality fails the
/// test however loaded the machine is.
void challenge(
  String name,
  Body body,
  List<Object?> smallest, {
  List<int> shrinks = everySeed,
}) {
  group(name, () {
    for (final int seed in everySeed) {
      final bool held = shrinks.contains(seed);
      test(
        held ? 'shrinks to $smallest from seed $seed' : 'fails from seed $seed',
        () async {
          final Outcome outcome = await PropertyRun(
            .new(),
            callSite: .of(.current),
            clock: FakeClock(),
            seed: seed,
          ).outcome(body);
          expect(outcome, held ? _shrinksTo(smallest) : isA<Failed>());
        },
      );
    }
  });
}

/// Matches a failed outcome whose smallest failing run drew [smallest], in
/// order.
Matcher _shrinksTo(List<Object?> smallest) => isA<Failed>().having(
  (Failed failed) => [for (final Drawn drawn in failed.run.draws) drawn.value],
  'values drawn',
  smallest,
);
