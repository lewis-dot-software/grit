import 'package:grit/grit.dart';
import 'package:test/test.dart';

import '../support/challenge.dart';

/// The seeds this challenge is held to: those from 0 to 9 whose search finds
/// a failure.
///
/// Seeds 0 and 1 find none, since a duplicate in a list of 32-bit integers
/// is drawn only where its choices fill at their bounds.
const List<int> _seeds = [2, 3, 4, 5, 6, 7, 8, 9];

/// A list of integers and an index into it from 0 to 10, under the false
/// property that removing the element at the index, by removing its first
/// instance, leaves none of it in the list.
void main() {
  challenge(
    'deletion',
    (Draw draw) {
      final List<int> list = draw(.list(.integer()));
      final int index = draw(.integer(min: 0, max: 10));
      draw.assume(index < list.length);
      final int element = list[index];
      expect([...list]..remove(element), isNot(contains(element)));
    },
    [
      [0, 0],
      0,
    ],
    seeds: _seeds,
  );
}
