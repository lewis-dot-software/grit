import 'package:grit/grit.dart';
import 'package:test/test.dart';

import '../support/challenge.dart';

/// The integer [value] wrapped to 16 bits, signed.
int _short(int value) => value.toSigned(16);

/// The 16-bit signed sum of [values], wrapping as it goes.
int _shortSum(Iterable<int> values) =>
    values.fold(0, (int sum, int value) => _short(sum + value));

/// The seeds past [everySeed] this challenge is held to as well.
const List<int> _moreSeeds = [19, 20, 28, 56, 59, 95, 97];

/// Five lists of 16-bit integers, each summing below 256, under the false
/// property that all five sum below 5 * 256, which wrapping breaks.
void main() {
  final Gen<List<int>> bounded = .list(
    .integer(min: -0x8000, max: 0x7FFF),
  ).filter((List<int> list) => _shortSum(list) < 256);

  challenge(
    'bound5',
    (Draw draw) {
      final List<List<int>> lists = [for (int i = 0; i < 5; i++) draw(bounded)];
      expect(
        _shortSum(lists.expand((List<int> list) => list)),
        lessThan(5 * 256),
      );
    },
    [
      <int>[],
      <int>[],
      <int>[],
      [-1],
      [-0x8000],
    ],
    moreSeeds: _moreSeeds,
  );
}
