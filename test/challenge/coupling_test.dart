import 'package:grit/grit.dart';
import 'package:test/test.dart';

import '../support/challenge.dart';

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
  );
}
