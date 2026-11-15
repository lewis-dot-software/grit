import 'package:grit/grit.dart';
import 'package:grit/src/api/property_run.dart';
import 'package:test/test.dart';

import 'fake_clock.dart';
import 'memory_store.dart';

/// The seeds every challenge is searched from.
const List<int> everySeed = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];

/// How many seeds, from 0, a challenge's benchmark searches from.
const int _benchSeeds = 100;

/// Declares a test for each of [everySeed] and each of [moreSeeds] that the
/// search of [body] from it, under the default settings, fails and shrinks to
/// the draws [smallest] holds, in order.
///
/// Declares as well a benchmark tagged `bench`, which the suite skips, that
/// searches [body] from each seed from 0 below [_benchSeeds] and prints from
/// how many the search failed, from how many of those shrinking reached
/// [smallest], and how many steps it ran over them all. A search that comes
/// to an outcome neither failed nor passed fails the benchmark.
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
        expect(await _search(body, seed), _shrinksTo(smallest));
      });
    }
    test(
      'counts shrinking steps over seeds 0 to ${_benchSeeds - 1}',
      tags: 'bench',
      () async {
        int found = 0;
        int hits = 0;
        int steps = 0;
        for (int seed = 0; seed < _benchSeeds; seed++) {
          switch (await _search(body, seed)) {
            case final Failed failed:
              found++;
              if (_shrinksTo(smallest).matches(failed, {})) hits++;
              steps += failed.steps;
            case Passed():
              break;
            case final Outcome outcome && (Flaky() || GaveUp()):
              fail('From seed $seed the search came to $outcome');
            case Reproduced() || NotReproduced():
              throw StateError('A search with no token replayed one');
          }
        }
        print(
          '$name: $found of $_benchSeeds seeds failed, $hits reached '
          '$smallest, in $steps steps',
        );
      },
    );
  });
}

/// The outcome of searching [body] from [seed] under the default settings,
/// timed by a clock that never moves and starting from an empty store.
Future<Outcome> _search(Body body, int seed) => PropertyRun(
  .new(),
  callSite: .of(.current),
  clock: FakeClock(),
  store: MemoryStore(),
  seed: seed,
).outcome(body);

/// Matches a failed outcome whose smallest failing run drew [smallest], in
/// order.
Matcher _shrinksTo(List<Object?> smallest) => isA<Failed>().having(
  (Failed failed) => [for (final Drawn drawn in failed.run.draws) drawn.value],
  'values drawn',
  smallest,
);
