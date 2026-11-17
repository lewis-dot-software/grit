import 'dart:async';
import 'dart:math';

import '../choice/choice_sequence.dart';
import '../choice/choice_source.dart';
import '../choice/decoding.dart';
import '../choice/odds.dart';
import '../choice/span.dart';
import '../choice/status.dart';
import '../choice/sweep.dart';
import '../gen/gen.dart';
import '../shrink/shrink.dart';
import '../store/loaded.dart';
import '../store/store.dart';
import 'body.dart';
import 'budget.dart';
import 'call_site.dart';
import 'clock.dart';
import 'failure.dart';
import 'first_found.dart';
import 'outcome.dart';
import 'run.dart';
import 'shrink_end.dart';
import 'warning.dart';

/// Everything grit does for one property: its runs, its shrinking and its
/// replays, ending in the property's outcome.
///
/// The failure the store holds for the call site replays first, and where
/// it fails, it is the first failure, with no generation. Otherwise
/// generation runs the body on random fills until one fails, [runs] runs
/// return, or [invalid] runs are rejected or overrun. A first failure is
/// replayed, shrunk under the budget, and replayed again, and either replay
/// that does not fail as it did makes the outcome flaky. The store then
/// holds a failed outcome's smallest failing sequence for the call site,
/// and nothing after any other outcome.
///
/// Generation is timed, and every outcome warns where the run count costs
/// more than 5 s at its mean time per run and that mean passes
/// [expectedRunTime], and where its runs were mostly
/// rejected or overrun in a search that did not give up. No warning changes
/// the verdict.
///
/// An error grit's own code throws inside a draw, one whose stack's first
/// frame outside the Dart SDK is grit's and that no [Gen.map] or
/// [Gen.filter] callback threw, leaves every phase as it was
/// thrown, with no outcome and the store as it stood, whether or not the
/// body caught it.
///
/// A failure is the same as another where [Failure.isAlike] says so, or
/// where each is a stack overflow, whatever its frame. A candidate that
/// fails any other way is told to the shrinker as not failing.
final class Search {
  /// A search filling from [random], timing generation and shrinking by
  /// [clock], called from [callSite] and keeping its failure in [store].
  ///
  /// [runs] is how many runs must return for the property to pass, [limit]
  /// the most choices one run may make, and [invalid] how many runs rejected
  /// or overrun give the search up. [invalid] is at least 1, and every other
  /// count never negative. [expectedRunTime] is the mean time a run is
  /// expected to take, at or under which the search never warns slow.
  Search({
    required this._clock,
    required this._random,
    required this._callSite,
    required this._store,
    required int runs,
    required int limit,
    required int invalid,
    required this._budget,
    required this._expectedRunTime,
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

  /// The time past which the run count, at generation's mean time per run,
  /// warns the property slow.
  static const Duration _slowAfter = .new(seconds: 5);

  final Clock _clock;
  final Random _random;
  final CallSite _callSite;
  final Store _store;
  final int _runs;
  final int _limit;
  final int _invalid;
  final Budget _budget;
  final Duration _expectedRunTime;

  /// The outcome of searching [body], the store's failure for the call site
  /// replayed first, with the warnings the search earned.
  Future<Outcome> run(Body body) async {
    final Outcome outcome = await _searched(body);
    switch (outcome) {
      case Failed(:final ChoiceSequence sequence):
        _store.save(_callSite.key, sequence);
      case Passed() || Flaky() || GaveUp():
        _store.delete(_callSite.key);
      case Reproduced() || NotReproduced():
        throw StateError('A search came to a token replay\'s outcome');
    }
    return outcome;
  }

  /// The outcome of [body]'s one run on [sequence], a replay token's, with
  /// no generation, no shrinking and no store.
  Future<Outcome> replay(Body body, ChoiceSequence sequence) async {
    final Run run = (await _replay(body, sequence)).run;
    return switch (run) {
      final Threw threw => Reproduced(threw),
      Returned() || Rejected() || Overran() => NotReproduced(run),
    };
  }

  /// The outcome of searching [body] from the store's failure, or from
  /// generation where the store holds none that fails.
  Future<Outcome> _searched(Body body) async {
    final List<Warning> stored = [];
    switch (_store.load(_callSite.key)) {
      case Stored(:final ChoiceSequence sequence):
        if ((await _replay(body, sequence)).run case final Threw first) {
          return _confirm(body, first, .stored, const []);
        }
      case Unreadable(:final Undecodable reason):
        stored.add(UnreadableStored(reason));
      case Unstored():
    }
    return _generated(body, stored);
  }

  /// The outcome of generating runs of [body], warning of [stored] and of
  /// what generation earns.
  Future<Outcome> _generated(Body body, List<Warning> stored) async {
    // An early run fills a choice at each edge it names in turn, the first
    // times it is made, so every one is filled. Its other choices fill
    // beside earlier choices and towards each choice's edges, so two wide
    // integers fall within one of each other in value, and a wide range
    // draws its ends, in the first few runs.
    final int early = (_runs + _earlyShare - 1) ~/ _earlyShare;
    final Sweep sweep = .new();
    final Duration start = _clock.elapsed;
    int returned = 0;
    int rejected = 0;
    int overran = 0;
    Threw? failed;
    generation:
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
          failed = first;
          break generation;
      }
      if (rejected + overran >= _invalid) break;
    }
    final Duration time = _clock.elapsed - start;
    final int made = returned + rejected + overran + (failed == null ? 0 : 1);
    final bool gaveUp = failed == null && returned < _runs;
    final List<Warning> warnings = [
      ...stored,
      // The mean time per run, times the run count against 5 s and alone
      // against the expected run time, compared in whole microseconds, so no
      // rounding of the mean moves either threshold.
      if (time.inMicroseconds * _runs > _slowAfter.inMicroseconds * made &&
          time.inMicroseconds > _expectedRunTime.inMicroseconds * made)
        SlowProperty(perRun: time ~/ made, runs: _runs),
      if (!gaveUp && rejected + overran > returned)
        MostlyInvalid(returned: returned, rejected: rejected, overran: overran),
    ];
    if (failed != null) return _confirm(body, failed, .generated, warnings);
    if (gaveUp) {
      return GaveUp(rejected: rejected, overran: overran, warnings: warnings);
    }
    return Passed(runs: returned, warnings: warnings);
  }

  /// The first replay of [first], found as [firstFound] says, then
  /// shrinking where it fails alike, the outcome warning of [warnings].
  Future<Outcome> _confirm(
    Body body,
    Threw first,
    FirstFound firstFound,
    List<Warning> warnings,
  ) async {
    final _Ran replay = await _replay(body, first.record);
    if (!first.failedAlike(replay.run)) {
      return Flaky(
        first,
        replay.run,
        firstFound: firstFound,
        warnings: warnings,
      );
    }
    return _shrink(body, first, firstFound, replay.spans, warnings);
  }

  /// Shrinking from [first], found as [firstFound] says, whose run made
  /// [spans], under the budget, then the final replay of the smallest
  /// failing sequence, the outcome warning of [warnings].
  ///
  /// The smallest failing sequence is the choices its run read, which may be
  /// fewer than the candidate it ran on holds.
  Future<Outcome> _shrink(
    Body body,
    Threw first,
    FirstFound firstFound,
    List<Span> spans,
    List<Warning> warnings,
  ) async {
    final Duration start = _clock.elapsed;
    final _Shrunk shrunk = await _shrunk(body, first, spans, start);
    final Duration time = _clock.elapsed - start;
    final ChoiceSequence smallest = shrunk.smallest.record;
    final Run replay = (await _replay(body, smallest)).run;
    return switch (replay) {
      final Threw last when first.failedAlike(last) => Failed(
        smallest,
        last,
        firstFound: firstFound,
        steps: shrunk.steps,
        time: time,
        end: shrunk.end,
        warnings: warnings,
      ),
      Threw() || Returned() || Rejected() || Overran() => Flaky(
        shrunk.smallest,
        replay,
        firstFound: firstFound,
        warnings: warnings,
      ),
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
    // The record a failing candidate's run read becomes the current sequence,
    // no larger than the candidate, and the step function proposes only
    // candidates smaller than that, so one told as failing is never proposed
    // again. Only those told as not failing repeat.
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
            // Its record becomes the current sequence, smaller than every
            // record told as failing before it.
            smallest = threw;
            shrink = shrink.toldFailing(
              read: threw.record.choices.length,
              spans: ran.spans,
            );
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
    // An error grit's own code threw inside a draw is a bug in grit, never
    // the property's failure, so it leaves the search unshrunk, whatever the
    // body did with it.
    for (final (:Error error, :StackTrace stackTrace) in draw.thrown) {
      if (CallSite.isGrits(stackTrace)) {
        Error.throwWithStackTrace(error, stackTrace);
      }
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
///   every candidate that failed alike.
/// - `steps`: how many candidates it ran.
/// - `end`: what ended it.
typedef _Shrunk = ({Threw smallest, int steps, ShrinkEnd end});

/// A run, with the span of each draw it made.
///
/// - `run`: the run, by how it ended.
/// - `spans`: the span of each draw it made, in the order the draws began.
typedef _Ran = ({Run run, List<Span> spans});
