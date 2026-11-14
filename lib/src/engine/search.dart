import 'dart:async';
import 'dart:math';

import '../choice/choice_sequence.dart';
import '../choice/choice_source.dart';
import '../choice/odds.dart';
import '../choice/span.dart';
import '../choice/status.dart';
import '../choice/sweep.dart';
import '../gen/gen.dart';
import '../shrink/shrink.dart';
import 'body.dart';
import 'budget.dart';
import 'call_site.dart';
import 'clock.dart';
import 'outcome.dart';
import 'run.dart';
import 'shrink_end.dart';

/// Everything grit does for one property: its runs, its shrinking and its
/// replays, ending in the property's outcome.
///
/// Generation runs the body on random fills until one fails, [runs] runs
/// return, or [invalid] runs are rejected or overrun. A failure is replayed,
/// shrunk under the budget, and replayed again, and either replay that does
/// not fail as the first failure did makes the outcome flaky.
///
/// A failure is the same as another where its error has the same type and
/// was thrown from the same frame, which [CallSite.failureOf] reads. A
/// candidate that fails any other way is told to the shrinker as not
/// failing.
final class Search {
  /// A search filling from [random] and timing shrinking by [clock], called
  /// from [callSite].
  ///
  /// [runs] is how many runs must return for the property to pass, [limit]
  /// the most choices one run may make, and [invalid] how many runs rejected
  /// or overrun give the search up. [invalid] is at least 1, and every other
  /// count never negative.
  Search({
    required this._clock,
    required this._random,
    required this._callSite,
    required int runs,
    required int limit,
    required int invalid,
    required this._budget,
  }) : _runs = RangeError.checkNotNegative(runs, 'runs'),
       _limit = RangeError.checkNotNegative(limit, 'limit'),
       _invalid = invalid >= 1
           ? invalid
           : throw RangeError.range(invalid, 1, null, 'invalid');

  /// The odds an early run fills a choice beside an earlier one along its
  /// zigzag, where the run has made one.
  static final Odds _near = .new(0.75);

  /// The odds an early run fills a choice at 0, at its bound or at an edge
  /// it names, where it fills it beside none.
  static final Odds _edges = .new(0.5);

  /// The share of the run count, one run in this many, made early, from the
  /// first run on.
  static const int _earlyShare = 5;

  final Clock _clock;
  final Random _random;
  final CallSite _callSite;
  final int _runs;
  final int _limit;
  final int _invalid;
  final Budget _budget;

  /// The outcome of searching [body].
  Future<Outcome> run(Body body) async {
    // An early run fills a choice at each edge it names in turn, the first
    // times it is made, so every one is filled. Its other choices fill
    // beside earlier choices and towards each choice's edges, so two wide
    // integers fall within one of each other in value, and a wide range
    // draws its ends, in the first few runs.
    final int early = (_runs + _earlyShare - 1) ~/ _earlyShare;
    final Sweep sweep = .new();
    int returned = 0;
    int rejected = 0;
    int overran = 0;
    for (int made = 0; returned < _runs; made++) {
      final bool isEarly = made < early;
      final ChoiceSource source = .random(
        _random,
        limit: _limit,
        sweep: isEarly ? sweep : null,
        near: isEarly ? _near : .never,
        edges: isEarly ? _edges : .never,
      );
      switch ((await _ran(body, source)).run) {
        case Returned():
          returned++;
          continue;
        case Rejected():
          rejected++;
        case Overran():
          overran++;
        case final Threw first:
          return _confirm(body, first);
      }
      if (rejected + overran >= _invalid) {
        return GaveUp(rejected: rejected, overran: overran);
      }
    }
    return Passed(runs: returned);
  }

  /// The first replay of [first], then shrinking where it fails alike.
  Future<Outcome> _confirm(Body body, Threw first) async {
    final _Ran replay = await _replay(body, first.record);
    if (!first.failedAlike(replay.run)) return Flaky(first, replay.run);
    return _shrink(body, first, replay.spans);
  }

  /// Shrinking from [first], whose run made [spans], under the budget, then
  /// the final replay of the smallest failing sequence.
  ///
  /// The smallest failing sequence is the choices its run read, which may be
  /// fewer than the candidate it ran on holds.
  Future<Outcome> _shrink(Body body, Threw first, List<Span> spans) async {
    final Duration start = _clock.elapsed;
    final _Shrunk shrunk = await _shrunk(body, first, spans, start);
    final Duration time = _clock.elapsed - start;
    final ChoiceSequence smallest = shrunk.smallest.record;
    final Run replay = (await _replay(body, smallest)).run;
    return switch (replay) {
      final Threw last when first.failedAlike(last) => Failed(
        smallest,
        last,
        steps: shrunk.steps,
        time: time,
        end: shrunk.end,
      ),
      Threw() ||
      Returned() ||
      Rejected() ||
      Overran() => Flaky(shrunk.smallest, replay),
    };
  }

  /// Where shrinking from [first], whose run made [spans], started at
  /// [start] by the clock, ends: at the step function's end, or where the
  /// budget runs out.
  Future<_Shrunk> _shrunk(
    Body body,
    Threw first,
    List<Span> spans,
    Duration start,
  ) async {
    // A candidate told as failing becomes the current sequence, and the step
    // function proposes only candidates smaller than that, so one told as
    // failing is never proposed again. Only those told as not failing repeat.
    final Set<ChoiceSequence> notFailing = {};
    Threw smallest = first;
    Shrink shrink = .start(first.record, spans);
    int steps = 0;
    _Shrunk ended(ShrinkEnd end) =>
        (smallest: smallest, steps: steps, end: end);
    while (true) {
      switch (shrink) {
        case Shrunk():
          return ended(.shrunk);
        case Shrinking(:final ChoiceSequence candidate)
            when notFailing.contains(candidate):
          shrink = shrink.toldNotFailing();
        case Shrinking(:final ChoiceSequence candidate):
          if (steps >= _budget.steps) return ended(.steps);
          if (_clock.elapsed - start >= _budget.time) return ended(.time);
          final _Ran ran = await _replay(body, candidate);
          steps++;
          if (ran.run case final Threw threw when first.failedAlike(threw)) {
            // A run may leave its candidate's tail unread, so a later
            // candidate smaller than the current sequence can read more than
            // the smallest failing run did.
            if (threw.record.isSmallerThan(smallest.record)) smallest = threw;
            shrink = shrink.toldFailing(ran.spans);
          } else {
            notFailing.add(candidate);
            shrink = shrink.toldNotFailing();
          }
      }
    }
  }

  /// A run of [body] on [sequence]'s choices alone.
  Future<_Ran> _replay(Body body, ChoiceSequence sequence) =>
      _ran(body, .fixed(sequence));

  /// A run of [body] on [source]'s choices.
  Future<_Ran> _ran(Body body, ChoiceSource source) async {
    final RunDraw draw = .new(source);
    (Object, StackTrace)? thrown;
    try {
      // A synchronous body is not awaited, so its run takes no turn of the
      // event loop.
      if (body(draw) case final Future<void> running) await running;
    } on Object catch (error, stackTrace) {
      thrown = (error, stackTrace);
    }
    final Status status = source.status(threw: thrown != null);
    final ChoiceSequence record = source.record;
    final Run run = switch ((status, thrown)) {
      (.failed, (final Object error, final StackTrace stackTrace)) => Threw(
        record,
        draw.draws,
        draw.notes,
        error: error,
        stackTrace: stackTrace,
        failure: _callSite.failureOf(error, stackTrace),
      ),
      (.overrun, _) => Overran(record, draw.draws, draw.notes),
      (.rejected, _) => Rejected(record, draw.draws, draw.notes),
      (.returned, null) => Returned(record, draw.draws, draw.notes),
      (.failed, null) || (.returned, _?) => throw StateError(
        'A run ended $status where its body ${thrown == null ? 'returned' : 'threw'}',
      ),
    };
    return (run: run, spans: draw.spans);
  }
}

/// Where a shrinking ended.
///
/// - `smallest`: the run with the smallest record of the first failure and
///   every candidate that failed alike, the earliest where two tie.
/// - `steps`: how many candidates it ran.
/// - `end`: what ended it.
typedef _Shrunk = ({Threw smallest, int steps, ShrinkEnd end});

/// A run, with the span of each draw it made.
///
/// - `run`: the run, by how it ended.
/// - `spans`: the span of each draw it made, in the order the draws began.
typedef _Ran = ({Run run, List<Span> spans});
