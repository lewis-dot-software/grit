import 'package:grit/grit.dart';
import 'package:grit/src/api/property_run.dart';
import 'package:test/test.dart';

import 'fake_clock.dart';
import 'memory_store.dart';

/// The seeds every challenge is searched from.
const List<int> everySeed = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];

/// Declares a test for each of [everySeed] and each of [moreSeeds] that the
/// search of [body] from it, under the default settings, fails and shrinks to
/// the draws [smallest] holds, in order.
///
/// The search is timed by a clock that never moves, so shrinking ends on its
/// own end or its step budget alone, and a fall in shrink quality fails the
/// test however loaded the machine is. Each search starts from an empty
/// store, so no failure an earlier one found shrinks in its place.
void challenge(
  String name,
  Body body,
  List<Object?> smallest, {
  List<int> moreSeeds = const [],
}) {
  group(name, () {
    for (final int seed in [...everySeed, ...moreSeeds]) {
      test('shrinks to $smallest from seed $seed', () async {
        final Outcome outcome = await PropertyRun(
          .new(),
          callSite: .of(.current),
          clock: FakeClock(),
          store: MemoryStore(),
          seed: seed,
        ).outcome(body);
        expect(outcome, _shrinksTo(smallest));
      });
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
