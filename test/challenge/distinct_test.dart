import 'package:grit/grit.dart';
import 'package:test/test.dart';

import '../support/challenge.dart';

/// A list of integers, under the false property that it holds fewer than
/// three distinct elements.
void main() {
  challenge(
    'distinct',
    (Draw draw) {
      final List<int> list = draw(.list(.integer()));
      expect(list.toSet(), hasLength(lessThan(3)));
    },
    [
      [0, 1, -1],
    ],
  );
}
