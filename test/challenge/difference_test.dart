import 'package:grit/grit.dart';
import 'package:test/test.dart';

import '../support/challenge.dart';

/// A body that draws two integers from [integer] and fails where the first
/// is at least 10 and [holds] fails on their absolute difference.
Body _differing(Gen<int> integer, bool Function(int difference) holds) =>
    (Draw draw) {
      final int first = draw(integer);
      final int second = draw(integer);
      if (first < 10) return;
      expect(holds((first - second).abs()), isTrue);
    };

/// Two integers, positive or from the default range across 0, under three
/// false properties of their absolute difference where the first is at
/// least 10.
void main() {
  for (final (String range, Gen<int> integer) in [
    ('positive', .integer(min: 1)),
    ('default', .integer()),
  ]) {
    group('over the $range range', () {
      challenge(
        'difference must not be zero',
        _differing(integer, (int difference) => difference != 0),
        [10, 10],
      );
      challenge(
        'difference must not be small',
        _differing(
          integer,
          (int difference) => difference < 1 || difference > 4,
        ),
        [10, 6],
      );
      challenge(
        'difference must not be one',
        _differing(integer, (int difference) => difference != 1),
        [10, 9],
      );
    });
  }
}
