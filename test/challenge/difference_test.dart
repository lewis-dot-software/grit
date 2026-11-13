import 'package:grit/grit.dart';
import 'package:test/test.dart';

import '../support/challenge.dart';

/// A body that draws two positive integers and fails where the first is at
/// least 10 and [holds] fails on their absolute difference.
Body _differing(bool Function(int difference) holds) => (Draw draw) {
  final int first = draw(.integer(min: 1));
  final int second = draw(.integer(min: 1));
  if (first < 10) return;
  expect(holds((first - second).abs()), isTrue);
};

/// Two positive integers, under three false properties of their absolute
/// difference where the first is at least 10.
void main() {
  challenge(
    'difference must not be zero',
    _differing((int difference) => difference != 0),
    [10, 10],
  );
  challenge(
    'difference must not be small',
    _differing((int difference) => difference < 1 || difference > 4),
    [10, 6],
  );
  challenge(
    'difference must not be one',
    _differing((int difference) => difference != 1),
    [10, 9],
  );
}
