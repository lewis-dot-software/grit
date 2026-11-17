import '../choice/choice_sequence.dart';
import '../gen/gen.dart';
import 'failure.dart';

/// One run of a property's body, by how it ended.
sealed class Run {
  Run._(this.record, this.draws, this.notes);

  /// The choices the run made, in order.
  final ChoiceSequence record;

  /// The values the body drew, in order.
  final List<Drawn> draws;

  /// The lines the body noted, in order.
  final List<String> notes;
}

/// A run whose body returned.
final class Returned extends Run {
  /// The run that returned, having made [record].
  Returned(super.record, super.draws, super.notes) : super._();
}

/// A run ended as invalid, which neither passed nor failed.
final class Rejected extends Run {
  /// The run rejected, having made [record].
  Rejected(super.record, super.draws, super.notes) : super._();
}

/// A run that asked for more choices than its source held.
final class Overran extends Run {
  /// The run that overran, having made [record].
  Overran(super.record, super.draws, super.notes) : super._();
}

/// A run whose body threw [error].
final class Threw extends Run {
  /// The run whose body threw [error] with [stackTrace], having made
  /// [record].
  Threw(
    super.record,
    super.draws,
    super.notes, {
    required this.error,
    required this.stackTrace,
    required this.failure,
  }) : super._();

  /// What the body threw.
  final Object error;

  /// Where the body threw it.
  final StackTrace stackTrace;

  /// The failure [error] is, by its type and the frame it was thrown from.
  final Failure failure;

  /// Whether [run] failed as this run did: its failure is alike this run's,
  /// or it threw a stack overflow from any frame where this run threw one,
  /// since an overflow strikes wherever the stack runs out.
  bool failedAlike(Run run) => switch ((error, run)) {
    (StackOverflowError(), Threw(error: StackOverflowError())) => true,
    (_, Threw(failure: final Failure theirs)) => theirs.isAlike(failure),
    (_, Returned() || Rejected() || Overran()) => false,
  };
}
