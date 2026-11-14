import '../choice/choice_sequence.dart';
import 'run.dart';
import 'shrink_end.dart';
import 'warning.dart';

/// What a search came to for one property, with what it warns of.
sealed class Outcome {
  Outcome._({this.warnings = const []});

  /// What the search warns of, none of which changed its verdict.
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
  /// last as [run], after a shrinking of [steps] steps that took [time] and
  /// ended on [end], warning of [warnings].
  Failed(
    this.sequence,
    this.run, {
    required this.steps,
    required this.time,
    required this.end,
    super.warnings,
  }) : super._();

  /// The smallest failing sequence shrinking found.
  final ChoiceSequence sequence;

  /// The final replay of [sequence], with its error, its draws and its notes.
  final Threw run;

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
  /// The outcome of [failed], whose sequence's replay [replay] did not fail
  /// as it did, warning of [warnings].
  Flaky(this.failed, this.replay, {super.warnings}) : super._();

  /// The run that failed.
  final Threw failed;

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
