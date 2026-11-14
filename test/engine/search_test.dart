import 'dart:math';

import 'package:grit/grit.dart';
import 'package:grit/src/choice/choice_source.dart';
import 'package:grit/src/choice/span.dart';
import 'package:grit/src/choice/status.dart';
import 'package:grit/src/engine/budget.dart';
import 'package:grit/src/engine/call_site.dart';
import 'package:grit/src/engine/clock.dart';
import 'package:grit/src/engine/search.dart';
import 'package:grit/src/gen/gen.dart';
import 'package:grit/src/shrink/shrink.dart';
import 'package:test/test.dart';

import '../support/fake_clock.dart';
import '../support/fixed_random.dart';
import '../support/inputs.dart';
import '../support/shrinking.dart';
import '../support/small.dart';

/// The call site of every search in this file.
final CallSite _callSite = .of(.current);

/// A budget no search here spends.
final Budget _unbounded = .new(steps: 1 << 30, time: .new(days: 1));

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
  Budget? budget,
}) => .new(
  clock: clock ?? FakeClock(),
  random: random ?? .new(seed),
  callSite: _callSite,
  runs: runs,
  limit: limit,
  invalid: invalid,
  budget: budget ?? _unbounded,
);

/// A choice from 0 to 3, whose value is the choice.
final Gen<int> _choice = .integer(min: 0, max: 3);

/// A random whose first run fills the choices 3 and 3.
Random get _fillsThreeThree => FixedRandom(0.9, ints: const [3, 3]);

/// The step bound at which shrinking [_readsSecondUnlessZero] from 3 and 3
/// has just accepted a candidate holding more choices than its run read,
/// read off the step function itself.
final int _tailedAt = () {
  final ChoiceSequence first = sequenceOf([3, 3]);
  // A search runs no candidate twice, so a repeat spends no step.
  final Set<ChoiceSequence> ran = {};
  for (
    Shrink shrink = .start(first, _readOf(first).spans);
    shrink is Shrinking;
  ) {
    final ChoiceSequence candidate = shrink.candidate;
    ran.add(candidate);
    final (:Status status, :ChoiceSequence record, :List<Span> spans) = _readOf(
      candidate,
    );
    if (status != .failed) {
      shrink = shrink.toldNotFailing();
      continue;
    }
    if (record.choices.length < candidate.choices.length) return ran.length;
    shrink = shrink.toldFailing(spans);
  }
  throw StateError('Shrinking 3 and 3 accepted no candidate past its read');
}();

/// How [_readsSecondUnlessZero]'s run on [sequence] ended, with the choices
/// and the spans its draws made.
({Status status, ChoiceSequence record, List<Span> spans}) _readOf(
  ChoiceSequence sequence,
) {
  final ChoiceSource source = .fixed(sequence);
  final RunDraw draw = .new(source);
  final Status status = run(source, () => _readsSecondUnlessZero()(draw));
  return (status: status, record: source.record, spans: draw.spans);
}

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
  'a branch': (Draw draw) {
    final List<int> record = [draw(.integer(min: 0, max: 1)), draw(_choice)];
    if (record[1] > 0 || record[0] == 0) {
      for (int i = 0; i < 3; i++) {
        record.add(draw(_choice));
      }
    }
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

/// A body's run on a fixed sequence:
///
/// - `way`: the way it failed, or [_Way.none].
/// - `record`: the choices it read.
/// - `spans`: the spans its draws made.
typedef _Ran = ({_Way way, ChoiceSequence record, List<Span> spans});

/// A body's first run that threw:
///
/// - `record`: the choices it read.
/// - `way`: the way it failed.
/// - `run`: its place among the body's runs.
typedef _First = ({ChoiceSequence record, _Way way, int run});

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
  _First? first;

  /// The records of the first run that threw and of every run after it that
  /// failed the same way, in order.
  final List<ChoiceSequence> failedAlike = [];

  void call(Draw draw) {
    final int run = runs++;
    final List<int> record = _shape(draw);
    final _Way way = _fails(run, record);
    if (way != .none) {
      first ??= (record: sequenceOf(record), way: way, run: run);
      if (way == first!.way) failedAlike.add(sequenceOf(record));
    }
    _throw(way);
  }

  /// Whether [sequence] is larger than a record of [failedAlike].
  bool isLargerThanAFailure(ChoiceSequence sequence) => failedAlike.any(
    (ChoiceSequence record) => record.isSmallerThan(sequence),
  );

  /// The way this body fails on [sequence]'s choices alone, read from its
  /// own rule and never from the search's reading of a stack, and
  /// [_Way.none] where its draws stop short.
  ///
  /// Only a body that fails as its record alone says has one way per sequence.
  _Way wayOn(ChoiceSequence sequence) => ranOn(sequence).way;

  /// The way this body fails on [sequence]'s choices alone, as [wayOn]
  /// reads it, with the choices and the spans its draws made.
  _Ran ranOn(ChoiceSequence sequence) {
    final ChoiceSource source = .fixed(sequence);
    final RunDraw draw = .new(source);
    late final List<int> record;
    final _Way way = switch (run(source, () => record = _shape(draw))) {
      .returned => _fails(0, record),
      .overrun || .rejected => .none,
      .failed => throw StateError('The shape of $name threw on $sequence'),
    };
    return (way: way, record: source.record, spans: draw.spans);
  }

  /// The oracle the search's shrinking of this body is told by: a candidate
  /// fails where it fails as the first failure did, making the spans its
  /// draws made, and [onRan] is told each candidate's run.
  List<Span>? Function(ChoiceSequence) failingAlike([
    void Function(_Ran ran)? onRan,
  ]) => (ChoiceSequence candidate) {
    final _Ran ran = ranOn(candidate);
    onRan?.call(ran);
    return ran.way == first!.way ? ran.spans : null;
  };

  /// The first state of the search's shrinking of this body's first failure.
  Shrink get shrinkStart {
    final ChoiceSequence record = first!.record;
    return .start(record, ranOn(record).spans);
  }

  /// How many candidates the search ran in shrinking: every run but
  /// generation's and the two replays.
  int get steps => runs - first!.run - 3;

  @override
  String toString() => name;
}

/// A body that draws an integer of as many values as each of its bounds in
/// turn, from as near half of them below 0, rejects the run where its first
/// value is 1, and fails where a value lies past [failsPast], logging each
/// run's values as it draws them.
///
/// Each value stands for one choice alone, so a run's log holds a value per
/// choice of the record it read, whether it returned, failed, was rejected
/// or overran. A range
/// across 0 names an edge, so the early runs' sweep fills it.
final class _Logging {
  _Logging(this._bounds, {required this.failsPast});

  final List<int> _bounds;

  /// The value past which a run fails.
  final int failsPast;

  /// The values of every run, in order.
  final List<List<int>> log = [];

  void call(Draw draw) {
    final List<int> run = [];
    log.add(run);
    for (final int bound in _bounds) {
      final int below = bound ~/ 2;
      run.add(draw(.integer(min: -below, max: bound - below)));
      if (run.length == 1) draw.assume(run.first != 1);
    }
    if (run.any((int x) => x > failsPast)) throw StateError('past');
  }
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
  Budget? budget,
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
/// and under as many milliseconds by a clock that moves one per read, against
/// [whole], its search with no bound, each reporting the choices its final
/// replay read, and returns whether the step bound ran out.
///
/// Each search runs a fresh copy of [body], at most [limit] choices per run.
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
    budget: .new(steps: bound, time: _unbounded.time),
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
    budget: .new(steps: _unbounded.steps, time: time),
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
/// failed, that it reports the smallest record of the runs shrinking accepted
/// where it accepts only the candidates [body] fails on as it first failed,
/// by its own rule, and returns how many candidates failed another way.
int _expectAcceptedAlike(_Body body, Outcome outcome) {
  expect(outcome, isNot(isA<Flaky>()), reason: '$body');
  if (outcome is! Failed) return 0;
  final _First first = body.first!;
  int crossed = 0;
  ChoiceSequence smallest = first.record;
  shrunk(
    body.shrinkStart,
    body.failingAlike((_Ran ran) {
      if (ran.way == first.way && ran.record.isSmallerThan(smallest)) {
        smallest = ran.record;
      }
      if (ran.way != .none && ran.way != first.way) crossed++;
    }),
  );
  expect(outcome.sequence, smallest, reason: '$body');
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
      int rejected = 0;
      int overran = 0;
      final Outcome outcome = await _search(runs: 30, limit: 2).run((
        Draw draw,
      ) {
        switch (draw(_choice)) {
          case 0:
            rejected++;
            draw.assume(false);
          case 1:
            overran++;
            draw(_choice);
            draw(_choice);
        }
      });
      expect(outcome, isA<Passed>().having((o) => o.runs, 'runs', 30));
      expect(rejected, greaterThan(0));
      expect(overran, greaterThan(0));
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
        budget: .new(steps: _tailedAt, time: _unbounded.time),
      ).run(_readsSecondUnlessZero()) as Failed;
      expect(failed.end, ShrinkEnd.steps);
      expect(failed.sequence, sequenceOf([0]));
      expect(failed.run.record, sequenceOf([0]));
    });

    test('is failed on the smallest record its failing runs read, where a '
        'smaller candidate after it read further', () async {
      // From a mode of 1 and a count of 5, lowering the count to 0 fails
      // reading 1 and 0 alone. A mode of 0 then fails on five choices, every
      // one smaller than the first candidate's tail.
      final Failed failed =
          await _search(random: FixedRandom(0.9, ints: const [1, 5, 5, 5, 5]))
                  .run((Draw draw) {
                    final int mode = draw(.integer(min: 0, max: 1));
                    final int count = draw(.integer(min: 0, max: 9));
                    if (count > 0 || mode == 0) {
                      for (int i = 0; i < 3; i++) {
                        draw(.integer(min: 0, max: 9));
                      }
                    }
                    throw StateError('always');
                  })
              as Failed;
      expect(failed.end, ShrinkEnd.shrunk);
      expect(failed.sequence, sequenceOf([1, 0]));
      expect(failed.run.record, sequenceOf([1, 0]));
    });

    test('is flaky, with the replay of its failed run\'s sequence, where the '
        'final replay does not fail as the first run did', () async {
      final Flaky flaky = await _search(
        random: _fillsThreeThree,
        budget: .new(steps: _tailedAt, time: _unbounded.time),
      ).run(_readsSecondUnlessZero(flakesOn: _tailedAt + 3)) as Flaky;
      expect(flaky.failed.record, sequenceOf([0]));
      expect(flaky.replay, isA<Overran>());
      expect(flaky.replay.record, flaky.failed.record);
    });

    test(
      'names the step bound where it ran out, at the first failure',
      () async {
        final Outcome outcome =
            await _search(budget: .new(steps: 0, time: _unbounded.time))
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
            await _search(
              budget: .new(steps: _unbounded.steps, time: .zero),
            ).run((Draw draw) {
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
      // The later runs' choices by tenth of the bound, the bound itself in
      // the last.
      const int tenths = 10;
      final List<int> laterByTenth = .filled(tenths, 0);
      int early = 0;
      int earlyEdges = 0;
      int later = 0;
      int laterEdges = 0;
      for (int seed = 0; seed < 10; seed++) {
        int run = 0;
        await _search(seed: seed, runs: 100).run((Draw draw) {
          final int x = draw(.integer(min: 0, max: bound));
          final bool edge = x == 0 || x == bound;
          // The first fifth of the run count is early.
          if (run++ < 20) {
            early++;
            if (edge) earlyEdges++;
          } else {
            later++;
            if (edge) laterEdges++;
            laterByTenth[min(x * tenths ~/ bound, tenths - 1)]++;
          }
        });
      }
      // A uniform fill puts 2 choices in 1001 at an edge.
      expect(earlyEdges / early, greaterThan(0.3));
      expect(laterEdges / later, lessThan(0.01));
      // A uniform fill puts about a tenth of 800 choices in each tenth, each
      // count's spread about 9, so a count past 30 off it is no uniform fill.
      for (int tenth = 0; tenth < tenths; tenth++) {
        expect(
          laterByTenth[tenth],
          inInclusiveRange(later ~/ tenths - 30, later ~/ tenths + 30),
          reason: 'choices in tenth $tenth of $laterByTenth',
        );
      }
    });
  });

  group('the random fill, beside earlier choices', () {
    test('fills two integers of one range within one of each other in value, '
        'and one apart, far more often on a search\'s early runs than a '
        'uniform fill would, and next to never on later runs, whether the '
        'range lies on one side of 0 or across it', () async {
      const int wide = 1 << 40;
      for (final Gen<int> integer in [
        .integer(min: 0, max: wide),
        .integer(min: -wide, max: wide),
        .integer(),
      ]) {
        int early = 0;
        int earlyBeside = 0;
        int earlyApart = 0;
        int later = 0;
        int laterBeside = 0;
        for (int seed = 0; seed < 10; seed++) {
          int run = 0;
          await _search(seed: seed, runs: 100).run((Draw draw) {
            final int x = draw(integer);
            final int y = draw(integer);
            final bool beside = (x - y).abs() <= 1;
            if (run++ < 20) {
              early++;
              if (beside) earlyBeside++;
              if ((x - y).abs() == 1) earlyApart++;
            } else {
              later++;
              if (beside) laterBeside++;
            }
          });
        }
        // A uniform fill puts two integers this wide within one of each
        // other next to never, and an edge fill at the same edge half the
        // time it fills both at an edge where the range names no other end,
        // and a third where it names one. A step of one choice beside an
        // earlier one falls on the other side of 0 across it, so the early
        // runs fill near half within one and few one apart where the step
        // is not taken by value.
        final String reason =
            'within one on $earlyBeside and one apart on $earlyApart of '
            '$early early';
        expect(earlyBeside / early, greaterThan(0.65), reason: reason);
        expect(earlyApart / early, greaterThan(0.25), reason: reason);
        expect(later, greaterThan(0));
        expect(laterBeside, 0);
      }
    });

    test('fills every choice that names an edge at it within a search\'s '
        'early runs from each of seeds 0 to 9, wherever the choice falls in '
        'its run, under the default run count', () async {
      // An integer across 0 names the choice of the end its bound does not
      // stand for, and each is drawn twice, so the second falls under the
      // bound of an earlier choice.
      final List<(int, int, int)> ranges = [
        (-1000000, 2000000, -1000000),
        (-5, 10, -5),
        (-10, 3, 3),
        (-0x80000000, 0x7FFFFFFF, 0x7FFFFFFF),
      ];
      for (int seed = 0; seed < 10; seed++) {
        final List<Set<int>> reached = [
          for (int i = 0; i < 2 * ranges.length; i++) {},
        ];
        int run = 0;
        await _search(seed: seed, runs: 100).run((Draw draw) {
          final bool early = run++ < 20;
          for (final (int i, (int min, int max, _)) in ranges.indexed) {
            for (int twice = 0; twice < 2; twice++) {
              final int x = draw(.integer(min: min, max: max));
              if (early) reached[2 * i + twice].add(x);
            }
          }
        });
        for (final (int i, (_, _, int named)) in ranges.indexed) {
          for (int twice = 0; twice < 2; twice++) {
            expect(
              reached[2 * i + twice],
              contains(named),
              reason: 'seed $seed, range $i, draw $twice',
            );
          }
        }
      }
    });
  });

  group('the random fill, at the edges a choice names', () {
    test('fills a choice that names an edge at it within a search\'s early '
        'runs from each of seeds 0 to 9, where the choice is made on some '
        'runs alone', () async {
      for (int seed = 0; seed < 10; seed++) {
        bool skipped = false;
        bool named = false;
        int run = 0;
        await _search(seed: seed, runs: 100).run((Draw draw) {
          final bool early = run++ < 20;
          if (!draw(.boolean())) {
            if (early) skipped = true;
            return;
          }
          final int x = draw(.integer(min: -1000000, max: 2000000));
          if (early && x == -1000000) named = true;
        });
        // An early run that skips the choice holds it to some runs alone.
        expect(
          (skipped: skipped, named: named),
          (skipped: true, named: true),
          reason: '$seed',
        );
      }
    });
  });

  group('shrinking', () {
    test('runs no candidate twice, running each the step function proposes '
        'once', () async {
      int repeated = 0;
      await _eachSearch((_Body body, _, Outcome outcome) async {
        if (outcome is! Failed) return;
        final Set<ChoiceSequence> proposed = {};
        int proposals = 0;
        final List<Span>? Function(ChoiceSequence) alike = body.failingAlike();
        shrunk(body.shrinkStart, (ChoiceSequence candidate) {
          proposals++;
          proposed.add(candidate);
          return alike(candidate);
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

    test('A failed outcome\'s sequence is never larger than any failing record '
        'shrinking found.', () async {
      int failed = 0;
      await _eachSearch((_Body body, _, Outcome outcome) async {
        if (outcome is! Failed) return;
        failed++;
        expect(
          body.isLargerThanAFailure(outcome.sequence),
          isFalse,
          reason: '$body',
        );
      });
      expect(failed, greaterThan(0));
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
        final Budget budget = .new(steps: 1 << 30, time: .new(milliseconds: 2));
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

  group('over every small logging body, each from a few seeds', () {
    test('A search from one seed fills the same sequences in the same '
        'order.', () async {
      int runs = 0;
      for (final ChoiceSequence bounds in everySequence(length: 3, bound: 3)) {
        for (final int failsPast in [0, 2, 4]) {
          for (final int limit in [2, 24]) {
            for (int seed = 0; seed < _seeds; seed++) {
              Future<List<List<int>>> filled() async {
                final _Logging body = .new([
                  for (final Choice c in bounds.choices) c.value,
                ], failsPast: failsPast);
                await _search(seed: seed, limit: limit).run(body.call);
                return body.log;
              }

              final List<List<int>> first = await filled();
              runs += first.length;
              expect(
                await filled(),
                first,
                reason:
                    'bounds $bounds, failing past $failsPast, limit '
                    '$limit, seed $seed',
              );
            }
          }
        }
      }
      expect(runs, greaterThan(0));
    });
  });

  group('a bug in grit', () {
    test('a negative setting, or a search that gives up on no invalid run, '
        'is thrown', () {
      for (final Search Function() make in [
        () => _search(runs: -1),
        () => _search(limit: -1),
        () => _search(invalid: 0),
      ]) {
        expect(make, throwsRangeError);
      }
    });

    test('a budget of negative steps or time is thrown', () {
      for (final Budget Function() make in [
        () => .new(steps: -1, time: .zero),
        () => .new(steps: 0, time: const .new(microseconds: -1)),
      ]) {
        expect(make, throwsRangeError);
      }
      expect(Budget(steps: 0, time: .zero).time, Duration.zero);
    });
  });

  group('on grit, over larger bodies', () {
    property('A search from one seed fills the same sequences in the same '
        'order.', (Draw draw) async {
      final List<int> bounds = draw(
        .list(anyChoice.map((Choice c) => c.value), maxLength: 6),
        label: 'bounds',
      );
      final int failsPast = draw(anyChoice, label: 'failing past').value;
      final int seed = draw(_anySeed, label: 'seed');
      final int limit = draw(.integer(min: 0, max: 8), label: 'limit');
      Future<List<List<int>>> filled() async {
        final _Logging body = .new(bounds, failsPast: failsPast);
        await _search(seed: seed, limit: limit).run(body.call);
        return body.log;
      }

      expect(await filled(), await filled());
    });

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

    test('A failed outcome\'s sequence is never larger than any failing record '
        'shrinking found.', () async {
      int failed = 0;
      await forAll((Draw draw) async {
        final _Body body = draw(_anyBody, label: 'body');
        final Outcome outcome = await _search(
          seed: draw(_anySeed, label: 'seed'),
          limit: _drawnLimit,
        ).run(body.call);
        if (outcome is! Failed) return;
        failed++;
        expect(body.isLargerThanAFailure(outcome.sequence), isFalse);
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
          final Budget budget = .new(
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
