import 'package:grit/src/gen/gen.dart';

import 'integer_range.dart';

/// Size ranges a check of a collection's long end covers: a narrow one from
/// 0, and a wide one far from 0.
const List<IntegerRange> sizeRanges = [
  (min: 0, max: 40),
  (min: 1001, max: 3999),
];

/// How many of 100 runs, each filled at random from its own seed under a run's
/// limit of choices, draw a value from [gen] whose [size] lies in the last
/// quarter of [range], which a size drawn evenly reaches in a quarter of them.
int longEndRuns<T>(Gen<T> gen, IntegerRange range, int Function(T value) size) {
  final int longEnd = range.max - (range.max - range.min) ~/ 4;
  int runs = 0;
  for (int seed = 0; seed < 100; seed++) {
    final T value = RunDraw(.random(.new(seed), limit: 8192))(gen);
    if (size(value) >= longEnd) runs++;
  }
  return runs;
}
