import 'package:grit/grit.dart';
import 'package:test/test.dart';

import '../support/challenge.dart';

/// The largest positive integer drawn.
const int _largest = 0x7FFFFFFF;

/// The choices of the positive integers [first] and [second], each its value
/// less 1.
List<int> _choices(int first, int second) => [first - 1, second - 1];

/// A body that draws two positive integers and fails where the first is at
/// least 10 and [holds] fails on their absolute difference.
Body _differing(bool Function(int difference) holds) => (Draw draw) {
  final int first = draw(.integer(min: 1));
  final int second = draw(.integer(min: 1));
  if (first < 10) return;
  expect(holds((first - second).abs()), isTrue);
};

/// The seeds from 0 to 9 whose search finds a failure where the difference
/// must not be zero, by filling both choices at their bound: the others find
/// none.
const List<int> _zeroSeeds = [0, 2, 6];

/// Two positive integers, under three false properties of their absolute
/// difference where the first is at least 10.
///
/// The default search finds a difference of 1 to 4 from no seed, since two
/// uniform choices over the positive integers fall a few apart too rarely,
/// so those two are shrunk from failures at the top of the range.
void main() {
  challenge(
    'difference must not be zero',
    _differing((int difference) => difference != 0),
    [10, 10],
    seeds: _zeroSeeds,
  );
  challengeFrom(
    'difference must not be small',
    _differing((int difference) => difference < 1 || difference > 4),
    [10, 6],
    starts: [
      _choices(_largest, _largest - 4),
      _choices(_largest - 4, _largest),
      _choices(_largest, _largest - 1),
    ],
  );
  challengeFrom(
    'difference must not be one',
    _differing((int difference) => difference != 1),
    [10, 9],
    starts: [
      _choices(_largest, _largest - 1),
      _choices(_largest - 1, _largest),
    ],
  );
}
