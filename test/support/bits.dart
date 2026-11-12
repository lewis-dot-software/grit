import 'package:grit/grit.dart';

/// A bit, 1 twice as often as 0, so a collection read from bits runs past
/// its minimum size more often than not.
final Gen<int> bit = .element([0, 1, 1]);

/// More zeros than any generator the suite checks reads to its end, wherever
/// the choices before them stop.
final List<int> zeros = .filled(1024, 0);

/// Runs of [bit] flattened, so a record reaches dozens of choices where one
/// collection's averages a handful.
final Gen<List<int>> bitRuns = .list(
  .list(bit),
).map((List<List<int>> runs) => [for (final List<int> run in runs) ...run]);
