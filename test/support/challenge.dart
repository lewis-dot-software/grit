import 'package:grit/grit.dart';
import 'package:grit/src/api/property_run.dart';
import 'package:grit/src/engine/search.dart';
import 'package:test/test.dart';

import 'fake_clock.dart';
import 'fixed_random.dart';

/// The seeds a challenge is searched from, unless it names its own.
const List<int> everySeed = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];

/// Declares a test for each of [seeds] that the search of [body] from it,
/// under the default settings, fails and shrinks to the draws [smallest]
/// holds, in order.
///
/// The search is timed by a clock that never moves, so shrinking ends on its
/// own end or its step budget alone, and a fall in shrink quality fails the
/// test however loaded the machine is.
void challenge(
  String name,
  Body body,
  List<Object?> smallest, {
  List<int> seeds = everySeed,
}) {
  group(name, () {
    for (final int seed in seeds) {
      test('shrinks to $smallest from seed $seed', () async {
        final Outcome outcome = await PropertyRun(
          .new(),
          callSite: .of(StackTrace.current),
          clock: FakeClock(),
          seed: seed,
        ).outcome(body);
        expect(outcome, _shrinksTo(smallest));
      });
    }
  });
}

/// Declares a test for each of [starts] that the search of [body], whose
/// first run fills each choice but a weighted one from that start in turn,
/// each weighted one at 0, and fails, shrinks under the default budget to the
/// draws [smallest] holds, in order.
///
/// The search is timed by a clock that never moves.
void challengeFrom(
  String name,
  Body body,
  List<Object?> smallest, {
  required List<List<int>> starts,
}) {
  group(name, () {
    for (final List<int> start in starts) {
      test('shrinks to $smallest from the choices $start', () async {
        final Settings settings = .new();
        final Outcome outcome = await Search(
          clock: FakeClock(),
          // A draw of 1 is never below an early run's odds of an edge, nor
          // below any weighted choice's odds, so every choice but a weighted
          // one is the next of the start's, and every weighted one is 0.
          random: FixedRandom(1, ints: start),
          callSite: .of(StackTrace.current),
          runs: 1,
          limit: start.length,
          invalid: 1,
          budget: (steps: settings.shrinkSteps, time: settings.shrinkTime),
        ).run(body);
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
