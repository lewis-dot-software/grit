import 'package:grit/grit.dart';

import 'generator.dart';

/// A bit, 1 twice as often as 0, so a collection read from bits runs past
/// its minimum size more often than not.
final Gen<int> bit = .element([0, 1, 1]);

/// Elements whose every choice is 0 or 1, and whose values are equal by
/// `==` where they are drawn alike, so a set of them drawn from bits sees
/// its repeats.
final List<Generator> bitElements = [
  .new('a boolean', .boolean()),
  .new('an integer from 0 to 1', .integer(min: 0, max: 1)),
  .new('an integer from -1 to 0', .integer(min: -1, max: 0)),
  .new('an element of a and b', .element(['a', 'b'])),
  .new(
    'a string of a and b up to 2 long',
    .string(alphabet: .of('ab'), maxLength: 2),
  ),
  .new(
    'one of a boolean and an element of x and y',
    .oneOf<Object>([
      .boolean(),
      .element(['x', 'y']),
    ]),
  ),
];

/// More zeros than any generator the suite checks reads to its end, wherever
/// the choices before them stop.
final List<int> zeros = .filled(1024, 0);

/// Runs of [bit] flattened, so a record reaches dozens of choices where one
/// collection's averages a handful.
final Gen<List<int>> bitRuns = .list(
  .list(bit),
).map((List<List<int>> runs) => [for (final List<int> run in runs) ...run]);
