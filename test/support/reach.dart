import 'package:grit/src/gen/gen.dart';

import 'integer_range.dart';

/// Size ranges a check of a collection's long end covers, each held whole by
/// a run's 8192 choices at two an element, as the generators doc's reach
/// figures ask: narrow ones from 0, one far from 0, and the widest from 0 the
/// run holds with a choice to end on.
const List<IntegerRange> sizeRanges = [
  (min: 0, max: 9),
  (min: 0, max: 40),
  (min: 0, max: 3200),
  (min: 1001, max: 3999),
  (min: 0, max: 4095),
];

/// How many runs a check of a collection's reach draws, enough that a share
/// drawn at the generators doc's odds stands clear of the figure it states.
const int reachRuns = 3000;

/// How far a collection's size reaches over [reachRuns] seeded runs:
///
/// - `atMax`: the share of runs whose size is its range's maximum.
/// - `lastQuarter`: the share of runs whose size lies in its range's last
///   quarter.
typedef Reach = ({double atMax, double lastQuarter});

/// The shares of [reachRuns] runs, each filled at random from its own seed
/// under a run's limit of choices, that draw a value from [gen] whose [size]
/// is [range]'s maximum, and whose [size] lies in its last quarter.
Reach reach<T>(Gen<T> gen, IntegerRange range, int Function(T value) size) {
  final int longEnd = range.max - (range.max - range.min) ~/ 4;
  int atMax = 0;
  int lastQuarter = 0;
  for (int seed = 0; seed < reachRuns; seed++) {
    final int drawn = size(RunDraw(.random(.new(seed), limit: 8192))(gen));
    if (drawn == range.max) atMax++;
    if (drawn >= longEnd) lastQuarter++;
  }
  return (atMax: atMax / reachRuns, lastQuarter: lastQuarter / reachRuns);
}
