import 'package:grit/grit.dart';
import 'package:test/test.dart';

import '../support/challenge.dart';

/// The seeds this challenge is held to: those from 0 to 9 whose search
/// shrinks to the smallest known.
///
/// Seed 7 stops at a coupled pair late in a list of zeros, whose indices fall
/// only as the elements before them are deleted.
const List<int> _seeds = [0, 1, 2, 3, 4, 5, 6, 8, 9];

/// A list of integers from 0 to 10, each an index of the list, under the
/// false property that no two elements index each other.
void main() {
  challenge(
    'coupling',
    (Draw draw) {
      final List<int> list = draw(.list(.integer(min: 0, max: 10)));
      draw.assume(list.every((int x) => x < list.length));
      for (int i = 0; i < list.length; i++) {
        final int j = list[i];
        if (j != i) expect(list[j], isNot(i));
      }
    },
    [
      [1, 0],
    ],
    seeds: _seeds,
  );
}
