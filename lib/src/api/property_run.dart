import 'dart:math';

import 'package:test/test.dart';

import '../choice/choice_sequence.dart';
import '../engine/call_site.dart';
import '../engine/clock.dart';
import '../engine/outcome.dart';
import '../engine/run.dart';
import '../engine/body.dart';
import '../engine/search.dart';
import '../engine/warning.dart';
import '../report/report.dart';
import '../store/file_store.dart';
import '../store/store.dart';
import '../report/warning_text.dart';
import 'settings.dart';
import 'settings_source.dart';
import 'stopwatch_clock.dart';

/// One search of a property from its settings, with its clock, its seed,
/// its call site and its store, and the test failure its outcome makes.
final class PropertyRun {
  /// The search of [settings], called from [callSite], timed by [clock],
  /// filled from [seed] and keeping its failure in [store].
  PropertyRun(
    this._settings, {
    required this._callSite,
    required this._clock,
    required this._store,
    required this.seed,
  });

  /// The search of [settings], called from [callSite], timed by a stopwatch,
  /// filled from the settings' seed, or a seed drawn now where they name
  /// none, and keeping its failure under `.dart_tool/grit/` in the working
  /// directory, the consumer's package as `dart test` runs it.
  factory PropertyRun.of(Settings settings, {required CallSite callSite}) =>
      .new(
        settings,
        callSite: callSite,
        clock: StopwatchClock(),
        store: FileStore(.new('.dart_tool/grit')),
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
  final Store _store;

  /// The seed the search's random choices are filled from.
  final int seed;

  /// The outcome of searching [body], or of replaying the settings' token
  /// alone where they name one.
  Future<Outcome> outcome(Body body) {
    final Search search = .new(
      clock: _clock,
      random: .new(seed),
      callSite: _callSite,
      store: _store,
      runs: _settings.runs,
      limit: _limit,
      invalid: _settings.runs * _invalidPerRun,
      budget: _settings.budget,
    );
    return switch (_settings.replayed) {
      null => search.run(body),
      final ChoiceSequence sequence => search.replay(body, sequence),
    };
  }

  /// Searches [body], and throws a [TestFailure] carrying the outcome's
  /// report on every outcome but [Passed], whose warnings it prints, one line
  /// each, under the test that stands.
  ///
  /// A failure that a run threw is thrown with that run's stack trace, so
  /// the test's failure points at the line of the body that threw.
  Future<void> check(Body body) async {
    final Outcome found = await outcome(body);
    switch (found) {
      case Passed(:final List<Warning> warnings):
        warnings.map(warningText).forEach(print);
      case Failed(:final Threw run) ||
          Flaky(failed: final Threw run) ||
          Reproduced(:final Threw run):
        Error.throwWithStackTrace(_failure(found), run.stackTrace);
      case GaveUp() || NotReproduced():
        throw _failure(found);
    }
  }

  TestFailure _failure(Outcome outcome) => .new(
    report(
      outcome,
      seed: seed,
      settings: _settings.source(seed: seed),
    ),
  );
}
