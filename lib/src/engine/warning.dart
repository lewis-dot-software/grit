import '../choice/decoding.dart';

/// What a search warns of, which never changes its verdict.
sealed class Warning {
  Warning._();
}

/// The property's runs are slow enough that its run count costs more than
/// the engine's threshold.
final class SlowProperty extends Warning {
  /// The warning of runs that took [perRun] each on average, in a search of
  /// [runs] runs.
  SlowProperty({required this.perRun, required this.runs}) : super._();

  /// The mean time of one run the search generated, by its clock.
  final Duration perRun;

  /// How many runs the search asked to return.
  final int runs;
}

/// More of the search's runs were rejected or overran than returned, in a
/// search that did not give up.
final class MostlyInvalid extends Warning {
  /// The warning of a search whose runs [returned], were [rejected] and
  /// [overran] as many times.
  MostlyInvalid({
    required this.returned,
    required this.rejected,
    required this.overran,
  }) : super._();

  /// How many runs returned.
  final int returned;

  /// How many runs were rejected.
  final int rejected;

  /// How many runs asked for more choices than the limit.
  final int overran;
}

/// The store held text for the call site that decodes to no sequence.
final class UnreadableStored extends Warning {
  /// The warning of stored text that decoded as [reason].
  UnreadableStored(this.reason) : super._();

  /// Why the stored text decodes to no sequence.
  final Undecodable reason;
}
