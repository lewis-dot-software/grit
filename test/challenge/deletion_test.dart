import 'package:grit/grit.dart';
import 'package:test/test.dart';

import '../support/challenge.dart';

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
  );
}
