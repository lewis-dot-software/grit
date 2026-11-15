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
import 'package:grit/src/store/loaded.dart';
import 'package:grit/src/store/store.dart';
import 'package:grit/src/store/store_key.dart';
import 'package:test/test.dart';

import '../support/bodies.dart';
import '../support/bottomless.dart';
import '../support/fake_clock.dart';
import '../support/fixed_random.dart';
import '../support/inputs.dart';
import '../support/memory_store.dart';
import '../support/shrinking.dart';
import '../support/small.dart';

/// The call site of every search in this file.
final CallSite _callSite = .of(.current);

/// A budget no search here spends.
final Budget _unbounded = .new(steps: 1 << 30, time: .new(days: 1));

/// The seeds the property checks search from.
const int _seeds = 3;

/// A search over [runs] runs of at most [limit] choices, from [seed], or
/// from [random] where it is given, keeping its failure in [store], an empty
/// one where none is given.
Search _search({
  int seed = 0,
  Random? random,
  Clock? clock,
  Store? store,
  int runs = 20,
  int limit = 24,
  int invalid = 100,
  Budget? budget,
}) => .new(
  clock: clock ?? FakeClock(),
  random: random ?? .new(seed),
  callSite: _callSite,
  store: store ?? MemoryStore(),
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
    shrink = shrink.toldFailing(read: record.choices.length, spans: spans);
  }
  throw StateError('Shrinking 3 and 3 accepted no candidate past its read');
}();

/// A run on a fixed sequence:
///
/// - `status`: how it ended.
/// - `record`: the choices it read.
/// - `spans`: the spans its draws made.
typedef _FixedRun = ({Status status, ChoiceSequence record, List<Span> spans});

/// How [_readsSecondUnlessZero]'s run on [sequence] ended, with the choices
/// and the spans its draws made.
_FixedRun _readOf(ChoiceSequence sequence) {
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

/// A body's run whose draws did not stop short:
///
/// - `run`: its place among the body's runs.
/// - `record`: the choices it read.
/// - `way`: the way it failed.
typedef _Read = ({int run, ChoiceSequence record, _Way way});

/// A body that draws as its shape says and fails as its [_fails] says of each
/// run's place and record, counting its runs and keeping the record of each
/// whose draws did not stop short, and that reads how it fails on a sequence
/// by its own rule.
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

  /// Each run whose draws did not stop short, in order.
  final List<_Read> read = [];

  void call(Draw draw) {
    final int run = runs++;
    final List<int> record = _shape(draw);
    final _Way way = _fails(run, record);
    read.add((run: run, record: sequenceOf(record), way: way));
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
  /// fails where it fails as the first failure did, having read the choices
  /// and made the spans its draws did, and [onRan] is told each candidate's
  /// run.
  Failing? Function(ChoiceSequence) failingAlike([
    void Function(_Ran ran)? onRan,
  ]) => (ChoiceSequence candidate) {
    final _Ran ran = ranOn(candidate);
    onRan?.call(ran);
    return ran.way == first!.way
        ? (read: ran.record.choices.length, spans: ran.spans)
        : null;
  };

  /// The first state of the search's shrinking of this body's first failure.
  Shrink get shrinkStart {
    final ChoiceSequence record = first!.record;
    return .start(record, ranOn(record).spans);
  }

  /// How many candidates the search ran in shrinking: every run but those
  /// up to the first that threw, and the first and final replays.
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

/// One search of the property checks:
///
/// - `body`: the body it searched, by name.
/// - `seed`: the seed it searched from.
typedef _Searched = ({String body, int seed});

/// An integer's range, and the edge it names:
///
/// - `min`: its minimum.
/// - `max`: its maximum.
/// - `named`: the value of the choice its bound does not stand for.
typedef _NamedEdge = ({int min, int max, int named});

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

/// Checks that each candidate [body]'s failed search ran in shrinking read a
/// record smaller than each record read before it by a run that failed as the
/// first failure did, and returns how many candidates it checked.
int _expectCandidatesSmaller(_Body body) {
  final _First first = body.first!;
  int checked = 0;
  ChoiceSequence smallest = first.record;
  for (final (:int run, :ChoiceSequence record, :_Way way) in body.read) {
    // The first failure and its replay come before shrinking, and the final
    // replay after.
    if (run <= first.run + 1 || run == body.runs - 1) continue;
    checked++;
    expect(record.isSmallerThan(smallest), isTrue, reason: '$body');
    if (way == first.way) smallest = record;
  }
  return checked;
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
    case Reproduced() || NotReproduced():
      fail('A search came to a token replay\'s outcome');
  }
}

/// How a search of a body that fails by its run's place came out.
enum _ByRun {
  /// It never failed.
  passed,

  /// The first and final replays failed as the first failure did.
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

/// How one run of a [_Scheduled] body ends.
enum _Ending { returns, rejects, overruns, throws }

/// A body whose runs end in turn as [endings] says, each run past their end
/// returning, and which overruns by drawing a choice, so a search of limit 0
/// overruns it.
final class _Scheduled {
  _Scheduled(this.endings);

  final List<_Ending> endings;
  int _calls = 0;

  void call(Draw draw) {
    final _Ending ending = _calls < endings.length ? endings[_calls] : .returns;
    _calls++;
    switch (ending) {
      case .returns:
        return;
      case .rejects:
        draw.assume(false);
      case .overruns:
        draw(_choice);
      case .throws:
        throw StateError('scheduled');
    }
  }

  /// How the runs of the search that ended on [outcome] ended while it
  /// generated: up to the first throw where the search found a failure,
  /// since each replay comes after, and every run otherwise.
  List<_Ending> generated(Outcome outcome) {
    final List<_Ending> ran = [
      for (int run = 0; run < _calls; run++)
        run < endings.length ? endings[run] : .returns,
    ];
    return switch (outcome) {
      Failed() || Flaky() => ran.sublist(0, ran.indexOf(.throws) + 1),
      Passed() || GaveUp() => ran,
      Reproduced() ||
      NotReproduced() => fail('A search came to a token replay\'s outcome'),
    };
  }

  @override
  String toString() => 'ending as $endings';
}

/// A search of a [_Scheduled] body:
///
/// - `body`: the body it searched.
/// - `outcome`: what it came to.
typedef _ScheduledSearch = ({_Scheduled body, Outcome outcome});

/// The search of a fresh [_Scheduled] body of [endings], over [runs] runs
/// that gives up at [invalid], timed by [clock], with the body it searched.
Future<_ScheduledSearch> _scheduled(
  List<_Ending> endings, {
  required int runs,
  required int invalid,
  Clock? clock,
}) async {
  final _Scheduled body = .new(endings);
  final Outcome outcome = await _search(
    runs: runs,
    limit: 0,
    invalid: invalid,
    clock: clock,
  ).run(body.call);
  return (body: body, outcome: outcome);
}

/// Calls [check] on every small schedule of run endings, with every small
/// run count and invalid limit.
Future<void> _eachSchedule(
  Future<void> Function(List<_Ending> endings, int runs, int invalid) check,
) async {
  for (final ChoiceSequence schedule in everySequence(length: 4, bound: 3)) {
    final List<_Ending> endings = [
      for (final Choice choice in schedule.choices) .values[choice.value],
    ];
    for (int runs = 1; runs <= 3; runs++) {
      for (int invalid = 1; invalid <= 3; invalid++) {
        await check(endings, runs, invalid);
      }
    }
  }
}

/// The clocks the verdict checks tick by, each moving by every small
/// sequence of ticks minutes long, so a search of any outcome warns slow on
/// some.
final List<List<Duration>> _slowClocks = [
  for (final ChoiceSequence ticks in everySequence(length: 2, bound: 2))
    [for (final Choice c in ticks.choices) .new(minutes: c.value)],
];

/// The slow-property warning of [outcome], or null where it has none.
SlowProperty? _slowOf(Outcome outcome) =>
    outcome.warnings.whereType<SlowProperty>().firstOrNull;

/// The mostly-invalid warning of [outcome], or null where it has none.
MostlyInvalid? _invalidOf(Outcome outcome) =>
    outcome.warnings.whereType<MostlyInvalid>().firstOrNull;

/// Checks that the search of a [_Scheduled] body of [endings], over [runs]
/// runs that gives up at [invalid], by a clock whose one tick lies [offset]
/// microseconds past the slow warning's threshold, is warned slow exactly
/// where its runs' mean time times [runs] passes 5 s, and returns whether it
/// was.
Future<bool> _expectSlowExactly(
  List<_Ending> endings, {
  required int runs,
  required int invalid,
  required int offset,
}) async {
  final (:_Scheduled body, :Outcome outcome) = await _scheduled(
    endings,
    runs: runs,
    invalid: invalid,
  );
  final int made = body.generated(outcome).length;
  // Generation reads the clock at its start and its end, so it takes one
  // tick, and the threshold falls between two ticks a microsecond apart.
  final int micros = 5000000 * made ~/ runs + offset;
  final (outcome: Outcome timed, body: _) = await _scheduled(
    endings,
    runs: runs,
    invalid: invalid,
    clock: FakeClock([.new(microseconds: micros)]),
  );
  final String reason = '$body, $runs runs, giving up at $invalid, $micros µs';
  final bool slow = micros * runs > 5000000 * made;
  expect(
    _slowOf(timed),
    slow
        ? isA<SlowProperty>()
              .having(
                (w) => w.perRun,
                'perRun',
                Duration(microseconds: micros ~/ made),
              )
              .having((w) => w.runs, 'runs', runs)
        : isNull,
    reason: reason,
  );
  return slow;
}

/// How a search's invalid runs stood beside those that returned.
enum _Invalid {
  /// They outnumbered them, and the search did not give up.
  warned,

  /// They outnumbered them, and the search gave up.
  outnumberedButGaveUp,

  /// They did not outnumber them.
  notOutnumbered,
}

/// Checks that the search of a [_Scheduled] body of [endings], over [runs]
/// runs that gives up at [invalid], is warned of its invalid runs, counting
/// each kind, exactly where they outnumber those that returned and it did not
/// give up, and returns how they stood.
Future<_Invalid> _expectInvalidExactly(
  List<_Ending> endings, {
  required int runs,
  required int invalid,
}) async {
  final (:_Scheduled body, :Outcome outcome) = await _scheduled(
    endings,
    runs: runs,
    invalid: invalid,
  );
  final List<_Ending> generated = body.generated(outcome);
  int count(_Ending ending) =>
      generated.where((_Ending ran) => ran == ending).length;
  final int returned = count(.returns);
  final int rejected = count(.rejects);
  final int overran = count(.overruns);
  final _Invalid stood = rejected + overran <= returned
      ? .notOutnumbered
      : outcome is GaveUp
      ? .outnumberedButGaveUp
      : .warned;
  expect(_invalidOf(outcome), switch (stood) {
    .warned =>
      isA<MostlyInvalid>()
          .having((w) => w.returned, 'returned', returned)
          .having((w) => w.rejected, 'rejected', rejected)
          .having((w) => w.overran, 'overran', overran),
    .outnumberedButGaveUp || .notOutnumbered => isNull,
  }, reason: '$body, $runs runs, giving up at $invalid');
  return stood;
}

/// A schedule of run endings, longer than the exhaustive checks reach.
final Gen<List<_Ending>> _anyEndings = .list(
  .element(_Ending.values),
  maxLength: 12,
);

/// A store holding [held] under this file's call site alone.
MemoryStore _holding(Loaded held) => .new({_callSite.key: held});

/// What [store] holds under this file's call site.
Loaded _heldIn(MemoryStore store) => store.load(_callSite.key);

/// Matches a load of [sequence].
Matcher _storedAs(ChoiceSequence sequence) => isA<Stored>().having(
  (Stored stored) => stored.sequence,
  'sequence',
  sequence,
);

/// What a store may hold for a call site before a search: nothing, text
/// that decodes to no sequence of either kind, or a few sequences.
List<Loaded> get _smallHeld => [
  Unstored(),
  Unreadable(NotAToken()),
  Unreadable(OtherFormat('grit0')),
  for (final List<int> values in [
    <int>[],
    [0],
    [3],
    [3, 3],
    [1, 2, 3],
  ])
    Stored(sequenceOf(values)),
];

/// What a store may hold for a call site before a search: nothing, text
/// that decodes to no sequence, or a sequence of small choices.
final Gen<Loaded> _anyHeld = .oneOf([
  .element([0]).map((_) => Unstored()),
  .element([NotAToken(), OtherFormat('grit0')]).map(Unreadable.new),
  smallSequence.map(Stored.new),
]);

/// A failure an outcome reports:
///
/// - `sequence`: the sequence it reports the failure on.
/// - `firstFound`: where the failure was first found.
typedef _Reported = ({ChoiceSequence sequence, FirstFound firstFound});

/// The sequence [outcome] reports its failure on: a failed outcome's
/// smallest, or the failed run's of a flaky one, with where it was first
/// found, or null where the outcome reports none.
_Reported? _reportedOf(Outcome outcome) => switch (outcome) {
  Failed(:final ChoiceSequence sequence, :final FirstFound firstFound) => (
    sequence: sequence,
    firstFound: firstFound,
  ),
  Flaky(:final Threw failed, :final FirstFound firstFound) => (
    sequence: failed.record,
    firstFound: firstFound,
  ),
  Passed() || GaveUp() || Reproduced() || NotReproduced() => null,
};

/// Bodies that fail by their run's place alone, as each small sequence of
/// ways says, returning on every run past its end, so a stored failure's
/// first replay can fail another way or not at all.
List<_Body Function()> get _byRun => [
  for (final ChoiceSequence ways in everySequence(length: 3, bound: 3))
    () => .new(
      'failing by run as $ways',
      _shapes['one choice']!,
      (int run, _) =>
          run < ways.choices.length ? .values[ways.choices[run].value] : .none,
    ),
];

/// An error grit's own code throws inside a draw.
enum _Grits {
  /// grit's own throw, of a range whose minimum lies above its maximum.
  outOfRange,

  /// A throw of the Dart SDK's, of a negative choice, beneath grit's code.
  negativeChoice;

  /// Throws this error from grit's own code.
  Never thrown() {
    switch (this) {
      case .outOfRange:
        Gen.integer(min: 1, max: 0);
      case .negativeChoice:
        Choice(-1);
    }
    throw StateError('grit threw no error for $name');
  }

  /// Matches this error, as grit's code threw it.
  Matcher get matcher => switch (this) {
    .outOfRange => isA<ArgumentError>().having(
      (ArgumentError e) => e.message,
      'message',
      'The minimum 1 is above the maximum 0',
    ),
    .negativeChoice =>
      isA<RangeError>()
          .having((RangeError e) => e.name, 'name', 'value')
          .having((RangeError e) => e.invalidValue, 'invalidValue', -1),
  };
}

/// Where a body's draw that grit's own code throws inside sits, and what the
/// body does with the error.
enum _Breaks {
  /// Drawn by the body, which leaves the error alone.
  drawn,

  /// Drawn as a list's element, which leaves it alone.
  nested,

  /// Drawn by the body, which catches the error and returns.
  caught,

  /// Drawn by the body, which catches the error and throws another.
  caughtThrowingAnother,
}

/// A body that draws a choice, then a generator grit's own code throws
/// [grits] inside, as [breaks] says, where the choice is [at], and fails
/// where the choice is [failsFrom] or more, logging its runs.
final class _Breaking {
  _Breaking(
    this.grits,
    this.breaks, {
    required this.at,
    required this.failsFrom,
  });

  final _Grits grits;
  final _Breaks breaks;
  final int at;
  final int failsFrom;

  /// How many runs there have been.
  int runs = 0;

  /// The run in which grit's code first threw, or null where it has not.
  int? brokeOn;

  /// Whether a run failed the body's own way before grit's code threw.
  bool failedFirst = false;

  late final Gen<int> _broken = .build((Draw draw) {
    brokeOn ??= runs;
    grits.thrown();
  });

  void call(Draw draw) {
    runs++;
    final int choice = draw(_choice);
    if (choice == at) {
      switch (breaks) {
        case .drawn:
          draw(_broken);
        case .nested:
          draw(.list(_broken, minLength: 1));
        case .caught:
          try {
            draw(_broken);
          } on Object {
            return;
          }
        case .caughtThrowingAnother:
          try {
            draw(_broken);
          } on Object {
            throw StateError('another');
          }
      }
    }
    if (choice >= failsFrom) {
      if (brokeOn == null) failedFirst = true;
      throw StateError('fails');
    }
  }

  @override
  String toString() =>
      '${grits.name} ${breaks.name} at $at, failing from $failsFrom';
}

/// Where a property's search starts from: generation from a seed, the stored
/// replay of a sequence, or a token's replay of one.
enum _From { generated, stored, token }

/// A way a property's search may start on a body:
///
/// - `from`: where the search starts from.
/// - `start`: a search of the body from it, storing in the store.
typedef _Start = ({
  _From from,
  Future<Outcome> Function(Body body, MemoryStore store) start,
});

/// A start a check reached a break of grit's from:
///
/// - `from`: where the search started from.
/// - `afterFailure`: whether the body failed before it broke.
typedef _Reached = ({_From from, bool afterFailure});

/// Every small start of a search: generation from a few seeds, and the
/// stored replay and the token's replay of each one-choice sequence.
List<_Start> get _smallStarts => [
  for (int seed = 0; seed < _seeds; seed++)
    (
      from: .generated,
      start: (Body body, MemoryStore store) =>
          _search(seed: seed, store: store).run(body),
    ),
  for (int value = 0; value <= 3; value++) ...[
    (
      from: .stored,
      start: (Body body, MemoryStore store) {
        store.save(_callSite.key, sequenceOf([value]));
        return _search(store: store).run(body);
      },
    ),
    (
      from: .token,
      start: (Body body, MemoryStore store) =>
          _search(store: store).replay(body, sequenceOf([value])),
    ),
  ],
];

/// The error [start] throws, or null where it ends in an outcome.
Future<Object?> _thrownBy(Future<Outcome> Function() start) async {
  try {
    await start();
  } on Object catch (error) {
    return error;
  }
  return null;
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
      // The last candidate run is the one whose run read fewer choices.
      expect(failed.steps, _tailedAt);
      expect(failed.sequence, sequenceOf([0]));
      expect(failed.run.record, sequenceOf([0]));
    });

    test('shrinks through failing runs each reading less than the one '
        'before, where a candidate smaller than a failing one reads further '
        'than its record', () async {
      // From a mode of 1 and a count of 5, lowering the count to 0 fails
      // reading 1 and 0 alone. A mode of 0 fails on five choices, which a
      // candidate smaller than the first's five, and larger than 1 and 0,
      // holds.
      final List<ChoiceSequence> failing = [];
      final Failed failed =
          await _search(random: FixedRandom(0.9, ints: const [1, 5, 5, 5, 5]))
                  .run((Draw draw) {
                    final List<int> drawn = [
                      draw(.integer(min: 0, max: 1)),
                      draw(.integer(min: 0, max: 9)),
                    ];
                    if (drawn[1] > 0 || drawn[0] == 0) {
                      for (int i = 0; i < 3; i++) {
                        drawn.add(draw(.integer(min: 0, max: 9)));
                      }
                    }
                    failing.add(sequenceOf(drawn));
                    throw StateError('always');
                  })
              as Failed;
      expect(failed.end, ShrinkEnd.shrunk);
      expect(failed.sequence, sequenceOf([1, 0]));
      expect(failed.run.record, sequenceOf([1, 0]));
      // Generation's run and the first replay come before shrinking, and the
      // final replay after.
      final List<ChoiceSequence> shrinking = failing.sublist(
        2,
        failing.length - 1,
      );
      expect(shrinking, isNotEmpty);
      ChoiceSequence before = failing.first;
      for (final ChoiceSequence record in shrinking) {
        expect(record.isSmallerThan(before), isTrue, reason: '$failing');
        before = record;
      }
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

  group('the warnings', () {
    test('are none where generation is fast and its runs return', () async {
      final Outcome outcome = await _search().run((Draw draw) {
        draw(_choice);
      });
      expect(outcome.warnings, isEmpty);
    });

    test('of a generated outcome cannot be changed by whoever reads '
        'them', () async {
      final Outcome outcome = await _search(
        runs: 10,
        clock: FakeClock([const .new(seconds: 6)]),
      ).run((Draw draw) {});
      expect(outcome.warnings, [isA<SlowProperty>()]);
      expect(outcome.warnings.clear, throwsUnsupportedError);
    });

    test('warn slow, naming the time per run, where the run count passes 5 s '
        'at it', () async {
      // Generation reads the clock at its start and its end, so it takes one
      // tick over its 10 runs.
      final Outcome outcome = await _search(
        runs: 10,
        clock: FakeClock([const .new(seconds: 6)]),
      ).run((Draw draw) {});
      expect(outcome, isA<Passed>());
      expect(outcome.warnings, [
        isA<SlowProperty>()
            .having(
              (w) => w.perRun,
              'perRun',
              const Duration(milliseconds: 600),
            )
            .having((w) => w.runs, 'runs', 10),
      ]);
    });

    test('warn of mostly invalid runs, counting each kind, in a search that '
        'passed', () async {
      final (:Outcome outcome, body: _) = await _scheduled(
        [.rejects, .overruns, .rejects],
        runs: 2,
        invalid: 10,
      );
      expect(outcome, isA<Passed>());
      expect(outcome.warnings, [
        isA<MostlyInvalid>()
            .having((w) => w.returned, 'returned', 2)
            .having((w) => w.rejected, 'rejected', 2)
            .having((w) => w.overran, 'overran', 1),
      ]);
    });

    test('are carried on a failed and a flaky outcome, and a given-up one '
        'warns slow alone', () async {
      final FakeClock slow = .new([const .new(minutes: 1)]);
      int calls = 0;
      final Outcome failed = await _search(limit: 0, clock: slow).run((
        Draw draw,
      ) {
        if (calls++ == 0) draw.assume(false);
        throw StateError('always');
      });
      final (outcome: Outcome flaky, body: _) = await _scheduled(
        [.rejects, .throws],
        runs: 1,
        invalid: 10,
        clock: FakeClock([const .new(minutes: 1)]),
      );
      final (outcome: Outcome gaveUp, body: _) = await _scheduled(
        [.rejects],
        runs: 1,
        invalid: 1,
        clock: FakeClock([const .new(minutes: 1)]),
      );
      for (final Outcome outcome in [failed, flaky]) {
        expect(outcome.warnings, [
          isA<SlowProperty>(),
          isA<MostlyInvalid>()
              .having((w) => w.returned, 'returned', 0)
              .having((w) => w.rejected, 'rejected', 1),
        ]);
      }
      expect(failed, isA<Failed>());
      expect(flaky, isA<Flaky>());
      expect(gaveUp, isA<GaveUp>());
      expect(gaveUp.warnings, [isA<SlowProperty>()]);
    });
  });

  group('the store', () {
    test('replays its failure for the call site first, which is the first '
        'failure, found from the store, with no generation', () async {
      final _Body body = .new(
        'one choice, failing from [2]',
        _shapes['one choice']!,
        _failingFrom(sequenceOf([2])),
      );
      final Outcome outcome = await _search(
        store: _holding(Stored(sequenceOf([3]))),
      ).run(body.call);
      expect(
        outcome,
        isA<Failed>()
            .having((o) => o.firstFound, 'firstFound', FirstFound.stored)
            .having((o) => o.sequence, 'sequence', sequenceOf([2])),
      );
      expect(body.first!.record, sequenceOf([3]));
      expect(body.first!.run, 0);
      // The stored replay, the first replay, each step and the final replay,
      // and no run of generation's.
      expect(body.runs, (outcome as Failed).steps + 3);
    });

    test('passes a stored sequence that does not fail over to generation, '
        'which finds its own failure', () async {
      final MemoryStore store = _holding(Stored(sequenceOf([0])));
      final Outcome outcome = await _search(store: store).run(
        _Body(
          'one choice, failing from [2]',
          _shapes['one choice']!,
          _failingFrom(sequenceOf([2])),
        ).call,
      );
      expect(
        outcome,
        isA<Failed>()
            .having((o) => o.firstFound, 'firstFound', FirstFound.generated)
            .having((o) => o.sequence, 'sequence', sequenceOf([2])),
      );
      expect(_heldIn(store), _storedAs(sequenceOf([2])));
    });

    test('passes a stored sequence that is rejected or overruns over to '
        'generation, and holds nothing after its pass', () async {
      for (final List<int> values in [
        [9],
        <int>[],
      ]) {
        final MemoryStore store = _holding(Stored(sequenceOf(values)));
        final Outcome outcome = await _search(store: store).run((Draw draw) {
          draw(_choice);
        });
        expect(outcome, isA<Passed>(), reason: '$values');
        expect(_heldIn(store), isA<Unstored>(), reason: '$values');
      }
    });

    test(
      'holds a failed outcome\'s smallest sequence after its search',
      () async {
        final MemoryStore store = .new();
        final Failed failed =
            await _search(store: store).run(failsOnTrue) as Failed;
        expect(_heldIn(store), _storedAs(failed.sequence));
      },
    );

    test('holds nothing after a passed, flaky or gave-up outcome, whatever '
        'it held before', () async {
      final Map<Type, Body Function()> bodies = {
        Passed: () => (Draw draw) {
          draw(_choice);
        },
        Flaky: failsOnce,
        GaveUp: () =>
            (Draw draw) => draw.assume(false),
      };
      for (final MapEntry(key: Type type, value: Body Function() make)
          in bodies.entries) {
        for (final Loaded held in _smallHeld) {
          final MemoryStore store = _holding(held);
          final Outcome outcome = await _search(store: store).run(make());
          expect(outcome.runtimeType, type, reason: '$type, holding $held');
          expect(
            _heldIn(store),
            isA<Unstored>(),
            reason: '$type, holding $held',
          );
        }
      }
    });

    test('deletes a stored failure that decodes to no sequence, warning of '
        'why, and generates as usual', () async {
      for (final Undecodable reason in [NotAToken(), OtherFormat('grit0')]) {
        final MemoryStore store = _holding(Unreadable(reason));
        final Outcome passed = await _search(store: store).run((Draw draw) {
          draw(_choice);
        });
        expect(passed, isA<Passed>().having((o) => o.runs, 'runs', 20));
        expect(
          passed.warnings.single,
          isA<UnreadableStored>().having((w) => w.reason, 'reason', reason),
        );
        expect(_heldIn(store), isA<Unstored>());
        final MemoryStore failing = _holding(Unreadable(reason));
        final Outcome failed = await _search(store: failing).run(failsOnTrue);
        expect(
          failed,
          isA<Failed>().having(
            (o) => o.warnings.single,
            'warning',
            isA<UnreadableStored>(),
          ),
        );
        expect(_heldIn(failing), _storedAs((failed as Failed).sequence));
      }
    });

    test('makes a stored failure whose first replay does not fail alike '
        'flaky, found from the store', () async {
      final MemoryStore store = _holding(Stored(sequenceOf([1])));
      final Outcome outcome = await _search(store: store).run(failsOnce());
      expect(
        outcome,
        isA<Flaky>()
            .having((o) => o.firstFound, 'firstFound', FirstFound.stored)
            .having((o) => o.failed.record, 'failed', sequenceOf([]))
            .having((o) => o.replay, 'replay', isA<Returned>()),
      );
      expect(_heldIn(store), isA<Unstored>());
    });

    test('keeps what another call site\'s key holds as it stood', () async {
      const StoreKey other = .new('file:///elsewhere_test.dart:1');
      final Loaded held = Stored(sequenceOf([3]));
      for (final Body body in [failsOnTrue, (Draw draw) {}]) {
        final MemoryStore store = .new({other: held});
        await _search(store: store).run(body);
        expect(store.held[other], same(held));
      }
    });
  });

  group('a token\'s replay', () {
    test('runs the body once on the token\'s sequence, reproduced where it '
        'throws', () async {
      final _Body body = .new(
        'two choices, failing from [1]',
        _shapes['two choices']!,
        _failingFrom(sequenceOf([1])),
      );
      final Outcome outcome = await _search().replay(
        body.call,
        sequenceOf([3, 2]),
      );
      expect(
        outcome,
        isA<Reproduced>()
            .having((o) => o.run.record, 'record', sequenceOf([3, 2]))
            .having((o) => o.run.error, 'error', isA<StateError>())
            .having((o) => o.warnings, 'warnings', isEmpty),
      );
      expect(body.runs, 1);
    });

    test('is not reproduced, with its run, where the run returns, is '
        'rejected or overruns', () async {
      final Map<List<int>, Matcher> runs = {
        [0, 0]: isA<Returned>(),
        [0, 9]: isA<Rejected>(),
        [0]: isA<Overran>(),
      };
      for (final MapEntry(key: List<int> values, value: Matcher run)
          in runs.entries) {
        final _Body body = .new(
          'two choices, failing from [1]',
          _shapes['two choices']!,
          _failingFrom(sequenceOf([1])),
        );
        final Outcome outcome = await _search().replay(
          body.call,
          sequenceOf(values),
        );
        expect(
          outcome,
          isA<NotReproduced>().having((o) => o.run, 'run', run),
          reason: '$values',
        );
        expect(body.runs, 1, reason: '$values');
      }
    });

    test('neither reads nor writes the store', () async {
      for (final Loaded held in _smallHeld) {
        final MemoryStore store = _holding(held);
        final Outcome outcome = await _search(store: store)
            .replay(failsOnTrue, sequenceOf([0]));
        expect(outcome, isA<NotReproduced>(), reason: '$held');
        expect(_heldIn(store), same(held));
      }
    });
  });

  group('over every small schedule of run endings', () {
    test('A property is warned slow exactly where its runs\' mean time times '
        'the run count passes 5 s.', () async {
      final Set<bool> warned = {};
      await _eachSchedule((List<_Ending> endings, int runs, int invalid) async {
        for (final int offset in [-1, 0, 1]) {
          warned.add(
            await _expectSlowExactly(
              endings,
              runs: runs,
              invalid: invalid,
              offset: offset,
            ),
          );
        }
      });
      expect(warned, {true, false});
    });

    test('A search is warned of its invalid runs exactly where they outnumber '
        'those that returned and it did not give up.', () async {
      final Set<_Invalid> reached = {};
      await _eachSchedule((List<_Ending> endings, int runs, int invalid) async {
        reached.add(
          await _expectInvalidExactly(endings, runs: runs, invalid: invalid),
        );
      });
      expect(reached, _Invalid.values.toSet());
    });
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

  group('an error grit\'s own code throws inside a draw', () {
    test('leaves generation as it was thrown, on the run that threw it, the '
        'store as it stood', () async {
      final _Breaking body = .new(.outOfRange, .drawn, at: 3, failsFrom: 4);
      final MemoryStore store = _holding(Unreadable(NotAToken()));
      await expectLater(
        _search(random: _fillsThreeThree, store: store).run(body.call),
        throwsA(_Grits.outOfRange.matcher),
      );
      expect((runs: body.runs, brokeOn: body.brokeOn), (runs: 1, brokeOn: 1));
      expect(_heldIn(store), isA<Unreadable>());
    });

    test('leaves shrinking unshrunk past the candidate it was thrown on, the '
        'store as it stood', () async {
      final _Breaking body = .new(.outOfRange, .drawn, at: 0, failsFrom: 1);
      final MemoryStore store = .new();
      await expectLater(
        _search(random: _fillsThreeThree, store: store).run(body.call),
        throwsA(_Grits.outOfRange.matcher),
      );
      expect(body.failedFirst, isTrue);
      expect(body.runs, body.brokeOn);
      expect(_heldIn(store), isA<Unstored>());
    });

    test('leaves the stored replay it was thrown on, the store holding its '
        'sequence as it stood', () async {
      final _Breaking body = .new(.outOfRange, .drawn, at: 2, failsFrom: 1);
      final MemoryStore store = _holding(Stored(sequenceOf([2])));
      await expectLater(
        _search(store: store).run(body.call),
        throwsA(_Grits.outOfRange.matcher),
      );
      expect((runs: body.runs, brokeOn: body.brokeOn), (runs: 1, brokeOn: 1));
      expect(_heldIn(store), _storedAs(sequenceOf([2])));
    });

    test(
      'leaves a token\'s replay as it was thrown, in place of reproduced',
      () async {
        final _Breaking body = .new(.outOfRange, .drawn, at: 1, failsFrom: 1);
        await expectLater(
          _search().replay(body.call, sequenceOf([1])),
          throwsA(_Grits.outOfRange.matcher),
        );
      },
    );

    test('leaves the search as it was thrown where the body catches it, '
        'returning or throwing another error', () async {
      for (final _Breaks breaks in [.caught, .caughtThrowingAnother]) {
        final _Breaking body = .new(.outOfRange, breaks, at: 1, failsFrom: 4);
        await expectLater(
          _search().replay(body.call, sequenceOf([1])),
          throwsA(_Grits.outOfRange.matcher),
          reason: '$body',
        );
      }
    });

    test('leaves the search as it was thrown where it leaves a draw inside '
        'another', () async {
      final _Breaking body = .new(.outOfRange, .nested, at: 1, failsFrom: 4);
      await expectLater(
        _search().replay(body.call, sequenceOf([1, 1, 0])),
        throwsA(_Grits.outOfRange.matcher),
      );
    });

    test('leaves the search as it was thrown where the Dart SDK throws it '
        'beneath grit\'s code', () async {
      final _Breaking body = .new(.negativeChoice, .drawn, at: 1, failsFrom: 4);
      await expectLater(
        _search().replay(body.call, sequenceOf([1])),
        throwsA(_Grits.negativeChoice.matcher),
      );
    });
  });

  group('a stack overflow inside a draw', () {
    test('is no change: leaves the search as it was thrown, unshrunk, the '
        'store as it stood', () async {
      final MemoryStore store = .new();
      await expectLater(
        _search(
          random: _fillsThreeThree,
          store: store,
        ).run((Draw draw) => draw(overflowing)),
        throwsA(isA<StackOverflowError>()),
      );
      expect(_heldIn(store), isA<Unstored>());
    });
  });

  group('a run that threw', () {
    /// A run that threw [error] from line [line] of the consumer's body.
    Threw threw(Object error, int line) {
      final StackTrace stackTrace = .fromString(
        '#0      body (package:app/src/body.dart:$line:3)',
      );
      return .new(
        sequenceOf([]),
        const [],
        const [],
        error: error,
        stackTrace: stackTrace,
        failure: _callSite.failureOf(error, stackTrace),
      );
    }

    test('failed alike another that overflowed the stack, whatever the frame '
        'each overflowed in', () {
      expect(
        threw(
          StackOverflowError(),
          15,
        ).failedAlike(threw(StackOverflowError(), 16)),
        isTrue,
      );
    });

    test('is no change: failed unlike another that threw its type from '
        'another frame, or another type from its frame', () {
      expect(
        threw(StateError('x'), 15).failedAlike(threw(StateError('x'), 16)),
        isFalse,
      );
      expect(
        threw(StackOverflowError(), 15).failedAlike(threw(StateError('x'), 15)),
        isFalse,
      );
      expect(
        threw(StateError('x'), 15).failedAlike(threw(StackOverflowError(), 15)),
        isFalse,
      );
    });
  });

  group(
    'a stack overflow outside any draw, the body noting as it recurses',
    () {
      test('is the property\'s failure, shrunk and stored, every note whole, '
          'never thrown out of the search', () async {
        for (int search = 0; search < 3; search++) {
          final MemoryStore store = .new();
          final Outcome outcome = await _search(
            random: _fillsThreeThree,
            store: store,
          ).run(notesOverflowing);
          expect(
            outcome,
            isA<Failed>()
                .having((o) => o.sequence, 'sequence', sequenceOf([1]))
                .having((o) => o.end, 'end', ShrinkEnd.shrunk)
                .having((o) => o.run.error, 'error', isA<StackOverflowError>())
                .having(
                  (o) => o.run.notes,
                  'notes',
                  allOf(isNotEmpty, everyElement('deeper')),
                ),
            reason: 'search $search',
          );
          expect(_heldIn(store), _storedAs(sequenceOf([1])));
        }
      });
    },
  );

  group('an error the body\'s own code throws inside a draw', () {
    test(
      'is no change: still the property\'s failure, shrunk, whether its '
      'code, the Dart SDK beneath it or a Dart SDK tear-off throws it',
      () async {
        final Map<String, Gen<int>> throwing = {
          'a build body\'s throw': .build((Draw draw) {
            final int x = draw(_choice);
            return x > 0 ? throw ArgumentError('the body\'s') : x;
          }),
          'a map\'s throw': _choice.map(
            (int x) => x > 0 ? throw RangeError('the body\'s') : x,
          ),
          'the Dart SDK\'s throw beneath a build body': .build(
            (Draw draw) => const [0][draw(_choice)],
          ),
          'a Dart SDK tear-off\'s throw as a map': _choice.map(
            const [0].elementAt,
          ),
          'a Dart SDK tear-off\'s throw as a filter': _choice.filter(
            const [true].elementAt,
          ),
        };
        for (final MapEntry(:String key, :Gen<int> value) in throwing.entries) {
          final Outcome outcome = await _search(random: _fillsThreeThree)
              .run((Draw draw) => draw(value));
          expect(
            outcome,
            isA<Failed>().having(
              (Failed failed) => failed.sequence,
              'sequence',
              sequenceOf([1]),
            ),
            reason: key,
          );
        }
      },
    );
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
      final List<_NamedEdge> ranges = [
        (min: -1000000, max: 2000000, named: -1000000),
        (min: -5, max: 10, named: -5),
        (min: -10, max: 3, named: 3),
        (min: -0x80000000, max: 0x7FFFFFFF, named: 0x7FFFFFFF),
      ];
      for (int seed = 0; seed < 10; seed++) {
        final List<Set<int>> reached = [
          for (int i = 0; i < 2 * ranges.length; i++) {},
        ];
        int run = 0;
        await _search(seed: seed, runs: 100).run((Draw draw) {
          final bool early = run++ < 20;
          for (final (int i, (:int min, :int max, named: _))
              in ranges.indexed) {
            for (int twice = 0; twice < 2; twice++) {
              final int x = draw(.integer(min: min, max: max));
              if (early) reached[2 * i + twice].add(x);
            }
          }
        });
        for (final (int i, (:int named, min: _, max: _)) in ranges.indexed) {
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
        final Failing? Function(ChoiceSequence) alike = body.failingAlike();
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
    test('After a search with no token, its call site\'s stored sequence is '
        'the smallest failing sequence of a failed outcome, and nothing '
        'after any other.', () async {
      final Set<Type> outcomes = {};
      for (final _Body Function() make in [..._deterministic, ..._byRun]) {
        for (final Loaded held in _smallHeld) {
          for (int seed = 0; seed < 2; seed++) {
            final _Body body = make();
            final MemoryStore store = _holding(held);
            final Outcome outcome = await _search(
              seed: seed,
              store: store,
            ).run(body.call);
            outcomes.add(outcome.runtimeType);
            final String reason = '$body from $seed, holding $held';
            switch (outcome) {
              case Failed(:final ChoiceSequence sequence):
                expect(_heldIn(store), _storedAs(sequence), reason: reason);
              case Passed() || Flaky() || GaveUp():
                expect(_heldIn(store), isA<Unstored>(), reason: reason);
              case Reproduced() || NotReproduced():
                fail('A search came to a token replay\'s outcome');
            }
          }
        }
      }
      expect(outcomes, {Passed, Failed, Flaky, GaveUp});
    });

    test('A failure found from a stored sequence is never reported larger '
        'than that sequence.', () async {
      final Set<Type> found = {};
      for (final _Body Function() make in [..._deterministic, ..._byRun]) {
        for (final ChoiceSequence stored in everySequence(
          length: 2,
          bound: 3,
        )) {
          final _Body body = make();
          final Outcome outcome = await _search(
            runs: 1,
            store: _holding(Stored(stored)),
          ).run(body.call);
          if (_reportedOf(outcome) case (
            sequence: final ChoiceSequence reported,
            firstFound: .stored,
          )) {
            found.add(outcome.runtimeType);
            expect(
              stored.isSmallerThan(reported),
              isFalse,
              reason: '$body, holding $stored',
            );
          }
        }
      }
      expect(found, {Failed, Flaky});
    });

    test('An error grit\'s own code throws inside a draw ends the test as '
        'grit\'s error, never as the property\'s failure.', () async {
      final Set<_Reached> reached = {};
      for (final _Grits grits in _Grits.values) {
        for (final _Breaks breaks in _Breaks.values) {
          for (int at = 0; at <= 3; at++) {
            for (int failsFrom = 0; failsFrom <= 4; failsFrom++) {
              for (final _Start start in _smallStarts) {
                final _Breaking body = .new(
                  grits,
                  breaks,
                  at: at,
                  failsFrom: failsFrom,
                );
                final MemoryStore store = .new();
                final Object? thrown = await _thrownBy(
                  () => start.start(body.call, store),
                );
                final String reason = '$body, ${start.from.name}';
                final int? brokeOn = body.brokeOn;
                if (brokeOn == null) {
                  expect(thrown, isNull, reason: reason);
                  continue;
                }
                reached.add((from: start.from, afterFailure: body.failedFirst));
                expect(thrown, grits.matcher, reason: reason);
                expect(body.runs, brokeOn, reason: reason);
                if (start.from != .stored) {
                  expect(_heldIn(store), isA<Unstored>(), reason: reason);
                }
              }
            }
          }
        }
      }
      expect(reached, <_Reached>{
        (from: .generated, afterFailure: false),
        (from: .generated, afterFailure: true),
        (from: .stored, afterFailure: false),
        (from: .stored, afterFailure: true),
        (from: .token, afterFailure: false),
      });
    });

    test('A token\'s replay runs the body once and leaves the store as it '
        'stood.', () async {
      for (final _Body Function() make in _deterministic) {
        for (final ChoiceSequence token in everySequence(length: 3, bound: 3)) {
          final _Body body = make();
          final MemoryStore store = _holding(
            _smallHeld[token.choices.length % _smallHeld.length],
          );
          final Map<StoreKey, Loaded> before = {...store.held};
          await _search(store: store).replay(body.call, token);
          expect(body.runs, 1, reason: '$body on $token');
          expect(store.held, before, reason: '$body on $token');
        }
      }
    });

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
      int failed = 0;
      await _eachSearch((_Body body, _, Outcome outcome) async {
        if (outcome is! Failed) return;
        failed++;
        expect(
          body.first!.record.isSmallerThan(outcome.sequence),
          isFalse,
          reason: '$body',
        );
      });
      expect(failed, greaterThan(0));
    });

    test('Every candidate\'s run reads a record smaller than each record read '
        'before it by a run that failed as the first failure did.', () async {
      int checked = 0;
      await _eachSearch((_Body body, _, Outcome outcome) async {
        if (outcome is Failed) checked += _expectCandidatesSmaller(body);
      });
      expect(checked, greaterThan(0));
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
        final Map<_Searched, Outcome> frozen = {};
        final Budget budget = .new(steps: 1 << 30, time: .new(milliseconds: 2));
        await _eachSearch(budget: budget, (
          _Body body,
          int seed,
          outcome,
        ) async {
          frozen[(body: '$body', seed: seed)] = outcome;
        });
        for (final List<Duration> ticks in clocks) {
          await _eachSearch(budget: budget, clock: () => FakeClock(ticks), (
            _Body body,
            int seed,
            Outcome outcome,
          ) async {
            _expectSameVerdict(
              outcome,
              frozen[(body: '$body', seed: seed)]!,
              reason: '$body from $seed, ticking $ticks',
            );
          });
        }
        expect(frozen.values.whereType<Passed>(), isNotEmpty);
        expect(frozen.values.whereType<Failed>(), isNotEmpty);
        expect(frozen.values.whereType<GaveUp>(), isNotEmpty);
      },
    );

    test('A warning never changes a verdict: one seed passes or fails alike '
        'whatever the clock reads.', () async {
      final Map<_Searched, Outcome> frozen = {};
      await _eachSearch((_Body body, int seed, Outcome outcome) async {
        frozen[(body: '$body', seed: seed)] = outcome;
      });
      // The verdicts a slow warning rode on, so the check reaches each.
      final Set<Type> warned = {};
      for (final List<Duration> ticks in _slowClocks) {
        await _eachSearch(clock: () => FakeClock(ticks), (
          _Body body,
          int seed,
          Outcome outcome,
        ) async {
          if (_slowOf(outcome) != null) warned.add(outcome.runtimeType);
          _expectSameVerdict(
            outcome,
            frozen[(body: '$body', seed: seed)]!,
            reason: '$body from $seed, ticking $ticks',
          );
        });
      }
      expect(frozen.values.map(_slowOf), everyElement(isNull));
      expect(warned, containsAll([Passed, Failed, GaveUp]));
    });

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
    test('a token replay\'s outcome of a run that threw, called not '
        'reproduced, is thrown', () {
      expect(
        () => NotReproduced(
          Threw(
            sequenceOf([]),
            const [],
            const [],
            error: StateError('x'),
            stackTrace: .empty,
            failure: (type: StateError, frame: null),
          ),
        ),
        throwsArgumentError,
      );
    });

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
    test('After a search with no token, its call site\'s stored sequence is '
        'the smallest failing sequence of a failed outcome, and nothing '
        'after any other.', () async {
      final Set<Type> outcomes = {};
      await forAll((Draw draw) async {
        final _Body body = draw(_anyBody, label: 'body');
        final MemoryStore store = _holding(draw(_anyHeld, label: 'held'));
        final Outcome outcome = await _search(
          seed: draw(_anySeed, label: 'seed'),
          limit: _drawnLimit,
          store: store,
        ).run(body.call);
        outcomes.add(outcome.runtimeType);
        switch (outcome) {
          case Failed(:final ChoiceSequence sequence):
            expect(_heldIn(store), _storedAs(sequence));
          case Passed() || Flaky() || GaveUp():
            expect(_heldIn(store), isA<Unstored>());
          case Reproduced() || NotReproduced():
            fail('A search came to a token replay\'s outcome');
        }
      });
      expect(outcomes, containsAll([Passed, Failed]));
    });

    test('A failure found from a stored sequence is never reported larger '
        'than that sequence.', () async {
      int found = 0;
      await forAll((Draw draw) async {
        final _Body body = draw(_anyBody, label: 'body');
        final ChoiceSequence stored = draw(smallSequence, label: 'stored');
        final Outcome outcome = await _search(
          runs: 1,
          limit: _drawnLimit,
          store: _holding(Stored(stored)),
        ).run(body.call);
        if (_reportedOf(outcome) case (
          sequence: final ChoiceSequence reported,
          firstFound: .stored,
        )) {
          found++;
          expect(stored.isSmallerThan(reported), isFalse);
        }
      });
      expect(found, greaterThan(0));
    });

    property('A token\'s replay runs the body once and leaves the store as it '
        'stood.', (Draw draw) async {
      final _Body body = draw(_anyBody, label: 'body');
      final MemoryStore store = _holding(draw(_anyHeld, label: 'held'));
      final Map<StoreKey, Loaded> before = {...store.held};
      await _search(
        limit: _drawnLimit,
        store: store,
      ).replay(body.call, draw(anySequence, label: 'token'));
      expect(body.runs, 1);
      expect(store.held, before);
    });

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

    test('Every candidate\'s run reads a record smaller than each record read '
        'before it by a run that failed as the first failure did.', () async {
      int checked = 0;
      await forAll((Draw draw) async {
        final _Body body = draw(_anyBody, label: 'body');
        final Outcome outcome = await _search(
          seed: draw(_anySeed, label: 'seed'),
          limit: _drawnLimit,
        ).run(body.call);
        if (outcome is Failed) checked += _expectCandidatesSmaller(body);
      });
      expect(checked, greaterThan(0));
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
      // 1249 of 3000 drawn cases ran out, so a seed misses this tally over
      // the default 100 runs about 1 in 10^23.
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
      // 916 of 3000 drawn cases crossed, so a seed misses this tally over
      // the default 100 runs about 1 in 10^16.
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
        // No case's check rests on a seed drawing every verdict. The reach
        // of each verdict rests on the twin over every small body.
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
          _expectSameVerdict(ticking, frozen);
        });
      },
    );

    test('A warning never changes a verdict: one seed passes or fails alike '
        'whatever the clock reads.', () async {
      await forAll((Draw draw) async {
        final _Body body = draw(_anyBody, label: 'body');
        final int seed = draw(_anySeed, label: 'seed');
        // Every read a minute or more on, so every ticking search warns slow
        // and no case's check rests on a slow clock being drawn. The reach of
        // each verdict rests on the twin over every small body.
        final List<Duration> ticks = draw(
          .list(
            .integer(
              min: 1,
              max: 3,
            ).map((int minutes) => .new(minutes: minutes)),
            minLength: 1,
          ),
          label: 'ticks',
        );
        final Outcome frozen = await _search(
          seed: seed,
          limit: _drawnLimit,
        ).run(body.call);
        final Outcome ticking = await _search(
          seed: seed,
          clock: FakeClock(ticks),
          limit: _drawnLimit,
        ).run(body.afresh.call);
        expect(_slowOf(frozen), isNull);
        expect(_slowOf(ticking), isNotNull);
        _expectSameVerdict(ticking, frozen);
      });
    });

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

    test('A property is warned slow exactly where its runs\' mean time times '
        'the run count passes 5 s.', () async {
      final Set<bool> warned = {};
      await forAll((Draw draw) async {
        warned.add(
          await _expectSlowExactly(
            draw(_anyEndings, label: 'endings'),
            runs: draw(.integer(min: 1, max: 16), label: 'runs'),
            invalid: draw(.integer(min: 1, max: 16), label: 'invalid'),
            offset: draw(.integer(min: -1, max: 1), label: 'offset'),
          ),
        );
      });
      expect(warned, {true, false});
    });

    test('A search is warned of its invalid runs exactly where they outnumber '
        'those that returned and it did not give up.', () async {
      // Every case's check is exact on its own, so none rests on a seed
      // drawing each way the runs can stand. The reach of each way rests on
      // the twin over every small schedule.
      await forAll((Draw draw) async {
        await _expectInvalidExactly(
          draw(_anyEndings, label: 'endings'),
          runs: draw(.integer(min: 1, max: 16), label: 'runs'),
          invalid: draw(.integer(min: 1, max: 16), label: 'invalid'),
        );
      });
    });
  });
}
