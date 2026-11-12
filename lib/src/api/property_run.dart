import 'dart:math';

import 'package:test/test.dart';

import '../engine/call_site.dart';
import '../engine/clock.dart';
import '../engine/outcome.dart';
import '../engine/run.dart';
import '../engine/search.dart';
import '../report/report.dart';
import 'settings.dart';
import 'stopwatch_clock.dart';

/// One search of a property from its settings, with its clock, its seed and
/// its call site, and the test failure its outcome makes.
final class PropertyRun {
  /// The search of [settings], called from [callSite], timed by [clock] and
  /// filled from [seed].
  PropertyRun(
    this._settings, {
    required this._callSite,
    required this._clock,
    required this.seed,
  });

  /// The search of [settings], called from [callSite], timed by a stopwatch
  /// and filled from the settings' seed, or a seed drawn now where they name
  /// none.
  factory PropertyRun.of(Settings settings, {required CallSite callSite}) =>
      .new(
        settings,
        callSite: callSite,
        clock: StopwatchClock(),
        seed: settings.seed ?? Random().nextInt(_seeds),
      );

  /// How many seeds a search draws from where its settings name none.
  static const int _seeds = 1 << 32;

  /// The most choices one run may make.
  static const int _limit = 8192;

  /// How many runs may be rejected or overrun for each run the settings ask
  /// to return, before the search gives up.
  static const int _invalidPerRun = 10;

  final Settings _settings;
  final CallSite _callSite;
  final Clock _clock;

  /// The seed the search's random choices are filled from.
  final int seed;

  /// The outcome of searching [body].
  Future<Outcome> outcome(Body body) => Search(
    clock: _clock,
    random: .new(seed),
    callSite: _callSite,
    runs: _settings.runs,
    limit: _limit,
    invalid: _settings.runs * _invalidPerRun,
    budget: (steps: _settings.shrinkSteps, time: _settings.shrinkTime),
  ).run(body);

  /// Searches [body], and throws a [TestFailure] carrying the outcome's
  /// report on every outcome but [Passed].
  ///
  /// A failure that a run threw is thrown with that run's stack trace, so
  /// the test's failure points at the line of the body that threw.
  Future<void> check(Body body) async {
    final Outcome found = await outcome(body);
    switch (found) {
      case Passed():
        return;
      case Failed(:final Threw run) || Flaky(failed: final Threw run):
        Error.throwWithStackTrace(_failure(found), run.stackTrace);
      case GaveUp():
        throw _failure(found);
    }
  }

  TestFailure _failure(Outcome outcome) => .new(report(outcome, seed: seed));
}
