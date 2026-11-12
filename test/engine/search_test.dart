import 'dart:math';

import 'package:grit/grit.dart';
import 'package:grit/src/engine/budget.dart';
import 'package:grit/src/engine/call_site.dart';
import 'package:grit/src/engine/clock.dart';
import 'package:grit/src/engine/search.dart';
import 'package:grit/src/shrink/shrink.dart';
import 'package:test/test.dart';

import '../support/fake_clock.dart';
import '../support/fixed_random.dart';
import '../support/shrinking.dart';
import '../support/small.dart';

/// The call site of every search in this file.
final CallSite _callSite = .of(StackTrace.current);

/// A budget no search here spends.
const Budget _unbounded = (steps: 1 << 30, time: .new(days: 1));

/// The seeds the property checks search from.
const int _seeds = 3;

/// A search over [runs] runs of at most [limit] choices, from [seed], or
/// from [random] where it is given.
Search _search({
  int seed = 0,
  Random? random,
  Clock? clock,
  int runs = 20,
  int limit = 24,
  int invalid = 100,
  Budget budget = _unbounded,
}) => .new(
  clock: clock ?? FakeClock(),
  random: random ?? Random(seed),
  callSite: _callSite,
  runs: runs,
  limit: limit,
  invalid: invalid,
  budget: budget,
);

/// A choice from 0 to 3, whose value is the choice.
final Gen<int> _choice = .integer(min: 0, max: 3);

/// A random whose first run fills the choices 3 and 3.
Random get _fillsThreeThree => FixedRandom(0.9, ints: const [3, 3]);

/// The step bound at which shrinking [_readsSecondUnlessZero] from 3 and 3
/// has just accepted 0 and 0, of which its run read the 0 alone.
const int _tailedAt = 4;

/// A body that always fails, reading a second choice where its first is not
/// 0, and on its [flakesOn]th run reading one more and failing another way.
Body _readsSecondUnlessZero({int? flakesOn}) {
  int runs = 0;
  return (Draw draw) {
    runs++;
    if (draw(_choice) != 0) draw(_choice);
    if (runs == flakesOn) {
      draw(_choice);
      throw ArgumentError('flaked');
    }
    throw StateError('always');
  };
}

/// How a body fails, if it does: a [StateError] or an [ArgumentError] from
/// one line, or a [StateError] from another.
enum _Way { none, stateHere, argumentHere, stateThere }

/// Throws as [way] says.
void _throw(_Way way) {
  switch (way) {
    case .none:
      return;
    case .stateHere || .argumentHere:
      throw way == .stateHere ? StateError('here') : ArgumentError('here');
    case .stateThere:
      throw StateError('there');
  }
}

/// What a body draws, returning the choices it read.
typedef _Shape = List<int> Function(Draw draw);

/// The shapes of draw the property checks take, each one whose choices are
/// its values, so a body reads back its own record.
final Map<String, _Shape> _shapes = {
  'one choice': (Draw draw) => [draw(_choice)],
  'two choices': (Draw draw) => [draw(_choice), draw(_choice)],
  'three choices': (Draw draw) => [draw(_choice), draw(_choice), draw(_choice)],
  'a list': (Draw draw) => [
    for (final int x in draw(.list(_choice))) ...[1, x],
    0,
  ],
  'a rare assumption': (Draw draw) {
    final List<int> record = [draw(_choice), draw(_choice)];
    draw.assume(record.every((int x) => x == 3));
    return record;
  },
  'an assumption': (Draw draw) {
    final int x = draw(_choice);
    draw.assume(x > 1);
    return [x, draw(_choice)];
  },
};

/// How a body fails on the [run]th of its runs, which read [record].
typedef _Fails = _Way Function(int run, List<int> record);

/// A body that draws as its shape says and fails as its [_fails] says,
/// logging each run.
final class _Body {
  _Body(this.name, this._shape, this._fails);

  final String name;
  final _Shape _shape;
  final _Fails _fails;

  /// How many runs there have been.
  int runs = 0;

  /// The same body, with no run yet.
  _Body get afresh => .new(name, _shape, _fails);

  /// The record of the first run that threw, with the way it failed and its
  /// place among the runs, where one has.
  ({ChoiceSequence record, _Way way, int run})? first;

  void call(Draw draw) {
    final int run = runs++;
    final List<int> record = _shape(draw);
    final _Way way = _fails(run, record);
    if (way != .none) {
      first ??= (record: sequenceOf(record), way: way, run: run);
    }
    _throw(way);
  }

  /// The way this body fails on [sequence]'s choices alone, read from its
  /// own rule and never from the search's reading of a stack, and
  /// [_Way.none] where its draws stop short.
  ///
  /// Only a body that fails as its record alone says has one way a sequence.
  _Way wayOn(ChoiceSequence sequence) {
    final List<int> record;
    try {
      record = _shape(Draw(.fixed(sequence)));
    } on Exception {
      // The source stopped the run, overrun or rejected.
      return .none;
    }
    return _fails(0, record);
  }

  /// How many candidates the search ran in shrinking: every run but
  /// generation's and the two replays.
  int get steps => runs - first!.run - 3;

  @override
  String toString() => name;
}

/// Fails where the record is at least [key], choice by choice.
_Fails _failingFrom(ChoiceSequence key) => (_, List<int> record) {
  final List<int> at = [for (final c in key.choices) c.value];
  final bool fails =
      record.length >= at.length &&
      [for (int i = 0; i < at.length; i++) i]
          .every((int i) => record[i] >= at[i]);
  return fails ? .stateHere : .none;
};

/// Fails in a way the record mixes with [key], so a smaller record often
/// fails another way.
_Fails _failingMixed(ChoiceSequence key) => (_, List<int> record) {
  int mix = key.choices.length;
  for (int i = 0; i < record.length; i++) {
    final int k = key.choices.isEmpty
        ? 1
        : key.choices[i % key.choices.length].value + 1;
    mix = mix * 5 + record[i] * k;
  }
  return .values[mix % _Way.values.length];
};

/// Bodies that fail as their record alone says, each built afresh.
List<_Body Function()> get _deterministic => [
  for (final MapEntry(key: String shape, value: _Shape draw) in _shapes.entries)
    for (final ChoiceSequence key in everySequence(length: 2, bound: 3)) ...[
      () => .new('$shape, failing from $key', draw, _failingFrom(key)),
      () => .new('$shape, failing mixed by $key', draw, _failingMixed(key)),
    ],
];

/// One part of a drawn body's shape, which draws as it says and returns the
/// choices it read.
sealed class _Part {
  _Part._(this.bound);

  /// The largest choice the part reads.
  final int bound;

  /// The choices the part reads, drawn through [draw].
  List<int> drawn(Draw draw);
}

/// A part that draws one choice.
final class _OneChoice extends _Part {
  _OneChoice(super.bound) : super._();

  @override
  List<int> drawn(Draw draw) => [draw(.integer(min: 0, max: bound))];

  @override
  String toString() => 'a choice up to $bound';
}

/// A part that draws a list of choices.
final class _ListOf extends _Part {
  _ListOf(super.bound) : super._();

  @override
  List<int> drawn(Draw draw) => [
    for (final int x in draw(.list(.integer(min: 0, max: bound)))) ...[1, x],
    0,
  ];

  @override
  String toString() => 'a list of choices up to $bound';
}

/// A part that draws one choice and rejects the run where it lies below
/// [least].
final class _AtLeast extends _Part {
  _AtLeast(super.bound, this.least) : super._();

  final int least;

  @override
  List<int> drawn(Draw draw) {
    final int x = draw(.integer(min: 0, max: bound));
    draw.assume(x >= least);
    return [x];
  }

  @override
  String toString() => 'a choice up to $bound, assumed at least $least';
}

/// The kinds of part a drawn body's shape is made of.
enum _PartKind { oneChoice, listOf, atLeast }

/// A part of any kind, reading choices up to a bound at one of a few scales.
final Gen<_Part> _anyPart = .build((Draw draw) {
  final int bound = draw(.element([3, 15, 255, 65535]));
  return switch (draw(.element(_PartKind.values))) {
    .oneChoice => _OneChoice(bound),
    .listOf => _ListOf(bound),
    .atLeast => _AtLeast(bound, draw(.integer(min: 0, max: bound))),
  };
});

/// A body that fails as its record alone says, drawing a shape of a few
/// parts and failing from a key, or mixed by it.
final Gen<_Body> _anyBody = .build((Draw draw) {
  final List<_Part> parts = draw(.list(_anyPart, maxLength: 6));
  final ChoiceSequence key = draw(
    .list(
      .integer(min: 0, max: 15).map(Choice.new),
      maxLength: 4,
    ).map(ChoiceSequence.new),
  );
  final bool mixed = draw(.boolean());
  return .new(
    '$parts, failing ${mixed ? 'mixed by' : 'from'} $key',
    (Draw draw) => [for (final _Part part in parts) ...part.drawn(draw)],
    mixed ? _failingMixed(key) : _failingFrom(key),
  );
});

/// A seed for a search grit draws.
final Gen<int> _anySeed = .integer(min: 0, max: 0xFFFFFFFF);

/// The most choices a run of a drawn body may make, past most of its lists.
const int _drawnLimit = 64;

/// Each deterministic body's search from each seed, with the body after it.
Future<void> _eachSearch(
  Future<void> Function(_Body body, int seed, Outcome outcome) check, {
  Budget budget = _unbounded,
  Clock Function()? clock,
}) async {
  for (final _Body Function() make in _deterministic) {
    for (int seed = 0; seed < _seeds; seed++) {
      final _Body body = make();
      final Outcome outcome = await _search(
        seed: seed,
        budget: budget,
        clock: clock?.call(),
      ).run(body.call);
      await check(body, seed, outcome);
    }
  }
}

/// Checks the searches of [body] from [seed] under a bound of [bound] steps,
/// and under as many milliseconds by a clock that moves one a read, against
/// [whole], its search with no bound, each reporting the choices its final
/// replay read, and returns whether the step bound ran out.
///
/// Each search runs a fresh copy of [body], at most [limit] choices a run.
Future<bool> _expectBounded(
  _Body body, {
  required int seed,
  required int bound,
  required Failed whole,
  int limit = 24,
}) async {
  final String reason = '$body from $seed, $bound steps';
  final _Body stepped = body.afresh;
  final Failed byStep = await _search(
    seed: seed,
    limit: limit,
    budget: (steps: bound, time: _unbounded.time),
  ).run(stepped.call) as Failed;
  expect(byStep.steps, stepped.steps, reason: reason);
  expect(byStep.sequence, byStep.run.record, reason: reason);
  expect(byStep.steps, lessThanOrEqualTo(bound), reason: reason);
  final bool ranOut = whole.steps > bound;
  if (ranOut) {
    expect(byStep.end, ShrinkEnd.steps, reason: reason);
    expect(byStep.steps, bound, reason: reason);
  } else {
    expect(byStep.end, ShrinkEnd.shrunk, reason: reason);
    expect(byStep.sequence, whole.sequence, reason: reason);
  }

  // Shrinking reads the clock once at its start and once before each run,
  // so a bound of as many milliseconds lets one run fewer start.
  final Duration time = .new(milliseconds: bound);
  final int allowed = bound == 0 ? 0 : bound - 1;
  final _Body timed = body.afresh;
  final Failed byTime = await _search(
    seed: seed,
    clock: FakeClock([const .new(milliseconds: 1)]),
    limit: limit,
    budget: (steps: _unbounded.steps, time: time),
  ).run(timed.call) as Failed;
  expect(byTime.steps, timed.steps, reason: '$reason, $time');
  expect(byTime.sequence, byTime.run.record, reason: '$reason, $time');
  if (whole.steps > allowed) {
    expect(byTime.end, ShrinkEnd.time, reason: '$reason, $time');
    expect(byTime.steps, allowed, reason: '$reason, $time');
    expect(byTime.time, greaterThanOrEqualTo(time), reason: '$reason, $time');
  } else {
    expect(byTime.end, ShrinkEnd.shrunk, reason: '$reason, $time');
    expect(byTime.sequence, whole.sequence, reason: '$reason, $time');
  }
  return ranOut;
}

/// Checks that [outcome], the search of [body], is never flaky, and where it
/// failed, that shrinking accepted only the candidates [body] fails on as it
/// first failed, by its own rule, and returns how many candidates failed
/// another way.
int _expectAcceptedAlike(_Body body, Outcome outcome) {
  expect(outcome, isNot(isA<Flaky>()), reason: '$body');
  if (outcome is! Failed) return 0;
  final ({ChoiceSequence record, _Way way, int run}) first = body.first!;
  int crossed = 0;
  final Shrunk alike = shrunk(.start(first.record), (ChoiceSequence candidate) {
    final _Way way = body.wayOn(candidate);
    if (way != .none && way != first.way) crossed++;
    return way == first.way;
  });
  expect(outcome.sequence, alike.current, reason: '$body');
  expect(body.wayOn(outcome.sequence), first.way, reason: '$body');
  return crossed;
}

/// Checks that [ticking] came to the verdict [frozen] did: a pass of as many
/// runs, a give-up of as many runs rejected and overrun, or a failure or a
/// flake of any size.
void _expectSameVerdict(Outcome ticking, Outcome frozen, {String? reason}) {
  switch (frozen) {
    case Passed(:final int runs):
      expect(
        ticking,
        isA<Passed>().having((o) => o.runs, 'runs', runs),
        reason: reason,
      );
    case GaveUp(:final int rejected, :final int overran):
      expect(
        ticking,
        isA<GaveUp>()
            .having((o) => o.rejected, 'rejected', rejected)
            .having((o) => o.overran, 'overran', overran),
        reason: reason,
      );
    case Failed():
      expect(ticking, isA<Failed>(), reason: reason);
    case Flaky():
      expect(ticking, isA<Flaky>(), reason: reason);
  }
}

/// How a search of a body that fails by its run's place came out.
enum _ByRun {
  /// It never failed.
  passed,

  /// Both replays failed as the first failure did.
  failed,

  /// The first replay did not fail as the first failure did.
  flakyOnFirstReplay,

  /// The first replay failed alike, and the final replay did not.
  flakyOnFinalReplay,
}

/// Checks [outcome], the search of [body], which fails as [at] says of each
/// run's place, against the replays it made, and returns how it came out.
_ByRun _expectFlakyUnlessReplayed(
  _Body body,
  _Way Function(int run) at,
  Outcome outcome, {
  String? reason,
}) {
  if (body.first == null) {
    expect(outcome, isA<Passed>(), reason: reason);
    return .passed;
  }
  final _Way first = at(body.first!.run);
  final bool replayed = at(body.first!.run + 1) == first;
  final bool lastReplayed = at(body.runs - 1) == first;
  if (replayed && lastReplayed) {
    expect(outcome, isA<Failed>(), reason: reason);
    return .failed;
  }
  expect(outcome, isA<Flaky>(), reason: reason);
  return replayed ? .flakyOnFinalReplay : .flakyOnFirstReplay;
}

void main() {
  group('an outcome', () {
    test('is passed, with its run count, where every run returns', () async {
      final Outcome outcome = await _search(runs: 30).run((Draw draw) {
        draw(_choice);
      });
      expect(outcome, isA<Passed>().having((o) => o.runs, 'runs', 30));
    });

    test('is passed where every run returns, however few invalid runs give '
        'it up', () async {
      final Outcome outcome = await _search(invalid: 1).run((Draw draw) {
        draw(_choice);
      });
      expect(outcome, isA<Passed>().having((o) => o.runs, 'runs', 20));
    });

    test('is passed past runs rejected or overrun within the limit', () async {
      final Outcome outcome = await _search(runs: 30).run((Draw draw) {
        draw.assume(draw(_choice) > 0);
      });
      expect(outcome, isA<Passed>().having((o) => o.runs, 'runs', 30));
    });

    test(
      'gives up, with its counts, where too many runs are rejected',
      () async {
        final Outcome outcome = await _search(invalid: 7).run((Draw draw) {
          draw.assume(false);
        });
        expect(
          outcome,
          isA<GaveUp>()
              .having((o) => o.rejected, 'rejected', 7)
              .having((o) => o.overran, 'overran', 0),
        );
      },
    );

    test('gives up, with its counts, where too many runs overrun', () async {
      final Outcome outcome = await _search(limit: 2, invalid: 5).run((
        Draw draw,
      ) {
        for (int i = 0; i < 3; i++) {
          draw(_choice);
        }
      });
      expect(
        outcome,
        isA<GaveUp>()
            .having((o) => o.rejected, 'rejected', 0)
            .having((o) => o.overran, 'overran', 5),
      );
    });

    test('is failed, with the final replay\'s error, draws and notes, and the '
        'steps and time shrinking took', () async {
      final FakeClock clock = .new([const .new(milliseconds: 1)]);
      final Outcome outcome = await _search(clock: clock).run((Draw draw) {
        final int x = draw(.integer(min: 0, max: 100), label: 'x');
        draw.note('x is $x');
        if (x >= 10) throw StateError('too large');
      });
      expect(outcome, isA<Failed>());
      final Failed failed = outcome as Failed;
      expect(failed.sequence, sequenceOf([10]));
      expect(failed.run.record, sequenceOf([10]));
      expect(failed.run.error, isA<StateError>());
      expect(failed.run.draws, [(label: 'x', value: 10, text: '10')]);
      expect(failed.run.notes, ['x is 10']);
      expect(failed.end, ShrinkEnd.shrunk);
      expect(failed.steps, greaterThan(0));
      expect(failed.time, greaterThan(Duration.zero));
    });

    test('is failed from an async body that awaits before it throws', () async {
      final Outcome outcome = await _search().run((Draw draw) async {
        final int x = draw(_choice);
        await Future<void>.value();
        if (x >= 2) throw StateError('async');
      });
      expect(
        outcome,
        isA<Failed>().having((o) => o.sequence, 'sequence', sequenceOf([2])),
      );
    });

    test('is flaky, with the replay, where the first replay does not fail as '
        'the first run did', () async {
      bool failedOnce = false;
      final Outcome outcome = await _search().run((Draw draw) {
        draw(_choice);
        if (!failedOnce) {
          failedOnce = true;
          throw StateError('once');
        }
      });
      expect(
        outcome,
        isA<Flaky>()
            .having((o) => o.failed.error, 'failed', isA<StateError>())
            .having((o) => o.replay, 'replay', isA<Returned>()),
      );
    });

    test('is failed on the choices its smallest failing run read, where '
        'the candidate it ran on held more', () async {
      final Failed failed = await _search(
        random: _fillsThreeThree,
        budget: (steps: _tailedAt, time: _unbounded.time),
      ).run(_readsSecondUnlessZero()) as Failed;
      expect(failed.end, ShrinkEnd.steps);
      expect(failed.sequence, sequenceOf([0]));
      expect(failed.run.record, sequenceOf([0]));
    });

    test('is flaky, with the replay of its failed run\'s sequence, where the '
        'final replay does not fail as the first run did', () async {
      final Flaky flaky = await _search(
        random: _fillsThreeThree,
        budget: (steps: _tailedAt, time: _unbounded.time),
      ).run(_readsSecondUnlessZero(flakesOn: _tailedAt + 3)) as Flaky;
      expect(flaky.failed.record, sequenceOf([0]));
      expect(flaky.replay, isA<Overran>());
      expect(flaky.replay.record, flaky.failed.record);
    });

    test(
      'names the step bound where it ran out, at the first failure',
      () async {
        final Outcome outcome =
            await _search(budget: (steps: 0, time: _unbounded.time))
                .run((Draw draw) {
                  if (draw(.integer(min: 0, max: 100)) >= 10) {
                    throw StateError('large');
                  }
                });
        expect(
          outcome,
          isA<Failed>()
              .having((o) => o.end, 'end', ShrinkEnd.steps)
              .having((o) => o.steps, 'steps', 0),
        );
      },
    );

    test(
      'names the time bound where it ran out, at the first failure',
      () async {
        final Outcome outcome =
            await _search(budget: (steps: _unbounded.steps, time: .zero))
                .run((Draw draw) {
                  if (draw(.integer(min: 0, max: 100)) >= 10) {
                    throw StateError('large');
                  }
                });
        expect(
          outcome,
          isA<Failed>()
              .having((o) => o.end, 'end', ShrinkEnd.time)
              .having((o) => o.steps, 'steps', 0),
        );
      },
    );
  });

  group('a run', () {
    test('that catches the source\'s stop and throws another error ends '
        'overrun, never failed', () async {
      final Outcome outcome = await _search(limit: 1, invalid: 3).run((
        Draw draw,
      ) {
        try {
          draw(_choice);
          draw(_choice);
        } on Exception {
          throw StateError('caught');
        }
      });
      expect(outcome, isA<GaveUp>().having((o) => o.overran, 'overran', 3));
    });
  });

  group('the random fill', () {
    test('draws a choice\'s 0 and its bound far more often on a search\'s '
        'early runs than a uniform fill would, and fills later runs '
        'uniformly', () async {
      const int bound = 1000;
      int early = 0;
      int earlyEdges = 0;
      int later = 0;
      int laterEdges = 0;
      for (int seed = 0; seed < 10; seed++) {
        int run = 0;
        await _search(seed: seed, runs: 100).run((Draw draw) {
          final int x = draw(.integer(min: 0, max: bound));
          final bool edge = x == 0 || x == bound;
          // The first tenth of the run count is early.
          if (run++ < 10) {
            early++;
            if (edge) earlyEdges++;
          } else {
            later++;
            if (edge) laterEdges++;
          }
        });
      }
      // A uniform fill puts 2 choices in 1001 at an edge.
      expect(earlyEdges / early, greaterThan(0.3));
      expect(laterEdges / later, lessThan(0.01));
    });
  });

  group('shrinking', () {
    test('runs no candidate twice, running each the step function proposes '
        'once', () async {
      int repeated = 0;
      await _eachSearch((_Body body, _, Outcome outcome) async {
        if (outcome is! Failed) return;
        final ({ChoiceSequence record, _Way way, int run}) first = body.first!;
        final Set<ChoiceSequence> proposed = {};
        int proposals = 0;
        shrunk(.start(first.record), (ChoiceSequence candidate) {
          proposals++;
          proposed.add(candidate);
          return body.wayOn(candidate) == first.way;
        });
        if (proposals > proposed.length) repeated++;
        expect(outcome.steps, proposed.length, reason: '$body');
        // The runs the body saw, so a candidate run twice shows whatever
        // the search counts.
        expect(body.steps, proposed.length, reason: '$body');
      });
      // The step function proposes a candidate again in some of them, so
      // the check reaches a repeat.
      expect(repeated, greaterThan(0));
    });
  });

  group('over every small body, each from a few seeds', () {
    test('A failed outcome\'s sequence fails again, the same way, when '
        'replayed.', () async {
      int failed = 0;
      await _eachSearch((_Body body, _, Outcome outcome) async {
        if (outcome is! Failed) return;
        failed++;
        expect(body.wayOn(outcome.sequence), body.first!.way, reason: '$body');
      });
      expect(failed, greaterThan(0));
    });

    test('A failed outcome\'s sequence is never larger than the first failure '
        'found.', () async {
      await _eachSearch((_Body body, _, Outcome outcome) async {
        if (outcome is! Failed) return;
        expect(
          body.first!.record.isSmallerThan(outcome.sequence),
          isFalse,
          reason: '$body',
        );
      });
    });

    test('Shrinking never runs more steps than its bound, an outcome whose '
        'bound ran out names that bound, and its sequence is the choices its '
        'final replay read.', () async {
      int failed = 0;
      await _eachSearch((_Body body, int seed, Outcome outcome) async {
        if (outcome is! Failed) return;
        failed++;
        for (final int bound in [0, 1, 2, 3, 5, 8]) {
          await _expectBounded(body, seed: seed, bound: bound, whole: outcome);
        }
      });
      expect(failed, greaterThan(0));
    });

    test('A candidate that fails with another error type or from another frame '
        'is never accepted.', () async {
      int crossed = 0;
      await _eachSearch((_Body body, _, Outcome outcome) async {
        crossed += _expectAcceptedAlike(body, outcome);
      });
      // Some candidate failed another way, so the check reaches the rule.
      expect(crossed, greaterThan(0));
    });

    test(
      'The clock never changes a verdict: the same seed passes or fails '
      'alike under any clock, and only the failure\'s size can differ.',
      () async {
        // Each clock moves by every small sequence of ticks, under a bound on
        // time a few ticks long. The bodies are deterministic, as the same
        // seed must be to repeat at all.
        final List<List<Duration>> clocks = [
          for (final ChoiceSequence ticks in everySequence(length: 2, bound: 2))
            [for (final c in ticks.choices) .new(milliseconds: c.value)],
        ];
        final Map<(String, int), Outcome> frozen = {};
        const Budget budget = (steps: 1 << 30, time: .new(milliseconds: 2));
        await _eachSearch(budget: budget, (
          _Body body,
          int seed,
          outcome,
        ) async {
          frozen[('$body', seed)] = outcome;
        });
        for (final List<Duration> ticks in clocks) {
          await _eachSearch(budget: budget, clock: () => FakeClock(ticks), (
            _Body body,
            int seed,
            Outcome outcome,
          ) async {
            _expectSameVerdict(
              outcome,
              frozen[('$body', seed)]!,
              reason: '$body from $seed, ticking $ticks',
            );
          });
        }
        expect(frozen.values.whereType<Passed>(), isNotEmpty);
        expect(frozen.values.whereType<Failed>(), isNotEmpty);
        expect(frozen.values.whereType<GaveUp>(), isNotEmpty);
      },
    );

    test('A body that fails once and not on replay ends flaky, never '
        'failed.', () async {
      // Each body fails as its run's place in every small sequence of ways
      // says, and returns on every run past the sequence's end.
      int flaky = 0;
      // Of them, those whose first replay failed alike and whose final
      // replay did not.
      int flakyLast = 0;
      for (final ChoiceSequence ways in everySequence(length: 4, bound: 3)) {
        _Way at(int run) => run < ways.choices.length
            ? .values[ways.choices[run].value]
            : .none;
        for (int seed = 0; seed < 2; seed++) {
          final _Body body = .new(
            'failing by run as $ways',
            _shapes['one choice']!,
            (int run, _) => at(run),
          );
          final Outcome outcome = await _search(
            seed: seed,
            runs: 3,
          ).run(body.call);
          switch (_expectFlakyUnlessReplayed(
            body,
            at,
            outcome,
            reason: '$body from $seed',
          )) {
            case .passed || .failed:
              break;
            case .flakyOnFirstReplay:
              flaky++;
            case .flakyOnFinalReplay:
              flaky++;
              flakyLast++;
          }
        }
      }
      expect(flaky, greaterThan(0));
      expect(flakyLast, greaterThan(0));
    });
  });

  group('a bug in grit', () {
    test('a negative setting, or a search that gives up on no invalid run, '
        'is thrown', () {
      for (final Search Function() make in [
        () => _search(runs: -1),
        () => _search(limit: -1),
        () => _search(invalid: 0),
        () => _search(budget: (steps: -1, time: .zero)),
        () => _search(budget: (steps: 0, time: const .new(microseconds: -1))),
      ]) {
        expect(make, throwsRangeError);
      }
    });
  });

  group('on grit, over larger bodies', () {
    test('A failed outcome\'s sequence fails again, the same way, when '
        'replayed.', () async {
      int failed = 0;
      await forAll((Draw draw) async {
        final _Body body = draw(_anyBody, label: 'body');
        final Outcome outcome = await _search(
          seed: draw(_anySeed, label: 'seed'),
          limit: _drawnLimit,
        ).run(body.call);
        if (outcome is! Failed) return;
        failed++;
        expect(body.wayOn(outcome.sequence), body.first!.way);
      });
      expect(failed, greaterThan(0));
    });

    test('A failed outcome\'s sequence is never larger than the first failure '
        'found.', () async {
      int failed = 0;
      await forAll((Draw draw) async {
        final _Body body = draw(_anyBody, label: 'body');
        final Outcome outcome = await _search(
          seed: draw(_anySeed, label: 'seed'),
          limit: _drawnLimit,
        ).run(body.call);
        if (outcome is! Failed) return;
        failed++;
        expect(body.first!.record.isSmallerThan(outcome.sequence), isFalse);
      });
      expect(failed, greaterThan(0));
    });

    test('Shrinking never runs more steps than its bound, an outcome whose '
        'bound ran out names that bound, and its sequence is the choices its '
        'final replay read.', () async {
      int ranOut = 0;
      await forAll((Draw draw) async {
        final _Body body = draw(_anyBody, label: 'body');
        final int seed = draw(_anySeed, label: 'seed');
        final int bound = draw(.integer(min: 0, max: 64), label: 'bound');
        final Outcome whole = await _search(
          seed: seed,
          limit: _drawnLimit,
        ).run(body.call);
        if (whole is! Failed) return;
        final bool spent = await _expectBounded(
          body,
          seed: seed,
          bound: bound,
          whole: whole,
          limit: _drawnLimit,
        );
        if (spent) ranOut++;
      });
      expect(ranOut, greaterThan(0));
    });

    test('A candidate that fails with another error type or from another frame '
        'is never accepted.', () async {
      int crossed = 0;
      await forAll((Draw draw) async {
        final _Body body = draw(_anyBody, label: 'body');
        final Outcome outcome = await _search(
          seed: draw(_anySeed, label: 'seed'),
          limit: _drawnLimit,
        ).run(body.call);
        crossed += _expectAcceptedAlike(body, outcome);
      });
      expect(crossed, greaterThan(0));
    });

    test(
      'The clock never changes a verdict: the same seed passes or fails '
      'alike under any clock, and only the failure\'s size can differ.',
      () async {
        final Set<Type> verdicts = {};
        await forAll((Draw draw) async {
          final _Body body = draw(_anyBody, label: 'body');
          final int seed = draw(_anySeed, label: 'seed');
          final List<Duration> ticks = draw(
            .list(
              .integer(min: 0, max: 3).map((int ms) => .new(milliseconds: ms)),
            ),
            label: 'ticks',
          );
          final Budget budget = (
            steps: _unbounded.steps,
            time: .new(
              milliseconds: draw(.integer(min: 0, max: 8), label: 'time'),
            ),
          );
          final Outcome frozen = await _search(
            seed: seed,
            limit: _drawnLimit,
            budget: budget,
          ).run(body.call);
          final Outcome ticking = await _search(
            seed: seed,
            clock: FakeClock(ticks),
            limit: _drawnLimit,
            budget: budget,
          ).run(body.afresh.call);
          verdicts.add(frozen.runtimeType);
          _expectSameVerdict(ticking, frozen);
        });
        expect(verdicts, containsAll([Passed, Failed, GaveUp]));
      },
    );

    test('A body that fails once and not on replay ends flaky, never '
        'failed.', () async {
      int flaky = 0;
      // Of them, those whose first replay failed alike and whose final
      // replay did not.
      int flakyLast = 0;
      await forAll((Draw draw) async {
        // The body fails as its run's place in the ways says, and returns on
        // every run past their end.
        final List<_Way> ways = draw(
          .list(.element(_Way.values)),
          label: 'ways',
        );
        _Way at(int run) => run < ways.length ? ways[run] : .none;
        final _Body body = .new(
          'failing by run as $ways',
          _shapes['one choice']!,
          (int run, _) => at(run),
        );
        final Outcome outcome = await _search(
          seed: draw(_anySeed, label: 'seed'),
          runs: draw(.integer(min: 1, max: 8), label: 'runs'),
        ).run(body.call);
        switch (_expectFlakyUnlessReplayed(body, at, outcome)) {
          case .passed || .failed:
            break;
          case .flakyOnFirstReplay:
            flaky++;
          case .flakyOnFinalReplay:
            flaky++;
            flakyLast++;
        }
      });
      expect(flaky, greaterThan(0));
      expect(flakyLast, greaterThan(0));
    });
  });
}
