import '../choice/choice_sequence.dart';
import 'first_found.dart';
import 'run.dart';
import 'shrink_end.dart';
import 'warning.dart';

/// What a search came to for one property, with what it warns of.
sealed class Outcome {
  Outcome._({List<Warning> warnings = const []})
    : warnings = .unmodifiable(warnings);

  /// What the search warns of, none of which changed its verdict, in a list
  /// that no one who reads it can change.
  final List<Warning> warnings;
}

/// Every run the search made returned, or was rejected or overran within its
/// limit, until the run count was spent.
final class Passed extends Outcome {
  /// The outcome of [runs] runs that returned, warning of [warnings].
  Passed({required this.runs, super.warnings}) : super._();

  /// How many runs returned.
  final int runs;
}

/// The property failed, and its smallest failing run failed again on the
/// final replay.
final class Failed extends Outcome {
  /// The outcome whose smallest failing sequence is [sequence], replayed
  /// last as [run], first found as [firstFound] says, after a shrinking of
  /// [steps] steps that took [time] and ended on [end], warning of
  /// [warnings].
  Failed(
    this.sequence,
    this.run, {
    required this.firstFound,
    required this.steps,
    required this.time,
    required this.end,
    super.warnings,
  }) : super._();

  /// The smallest failing sequence shrinking found.
  final ChoiceSequence sequence;

  /// The final replay of [sequence], with its error, its draws and its notes.
  final Threw run;

  /// Where the failure shrinking started from was found.
  final FirstFound firstFound;

  /// How many candidates shrinking ran.
  final int steps;

  /// How long shrinking took, by the search's clock.
  final Duration time;

  /// What ended shrinking: its own end, or the budget's bound that ran out.
  final ShrinkEnd end;
}

/// The property failed once, then did not fail as it did when the failing
/// sequence was replayed.
final class Flaky extends Outcome {
  /// The outcome of [failed], first found as [firstFound] says, whose
  /// sequence's replay [replay] did not fail as it did, warning of
  /// [warnings].
  Flaky(this.failed, this.replay, {required this.firstFound, super.warnings})
    : super._();

  /// The run that failed.
  final Threw failed;

  /// Where the failure was first found.
  final FirstFound firstFound;

  /// The replay of [failed]'s sequence, which did not fail as it did.
  final Run replay;
}

/// Too many runs were rejected or overran before the run count was spent.
final class GaveUp extends Outcome {
  /// The outcome of a search that saw [rejected] runs rejected and [overran]
  /// runs overrun, warning of [warnings].
  GaveUp({required this.rejected, required this.overran, super.warnings})
    : super._();

  /// How many runs were rejected.
  final int rejected;

  /// How many runs asked for more choices than the limit.
  final int overran;
}

/// The body failed on the one run a replay token's sequence made.
final class Reproduced extends Outcome {
  /// The outcome of [run], the token's replay, which threw.
  Reproduced(this.run) : super._();

  /// The replay of the token's sequence, with its error, its draws and its
  /// notes.
  final Threw run;
}

/// The one run a replay token's sequence made did not fail.
final class NotReproduced extends Outcome {
  /// The outcome of [run], the token's replay, which is never a run that
  /// threw.
  NotReproduced(this.run) : super._() {
    if (run is Threw) {
      throw ArgumentError.value(run, 'run', 'Must be a run that did not throw');
    }
  }

  /// The replay of the token's sequence: returned, rejected or overrun.
  final Run run;
}
