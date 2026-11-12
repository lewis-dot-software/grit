import 'package:grit/grit.dart';
import 'package:test/test.dart';

import '../support/challenge.dart';

/// A list of lists of integers, under the false property that they hold
/// fewer than five distinct integers between them.
void main() {
  challenge(
    'large union list',
    (Draw draw) {
      final List<List<int>> lists = draw(.list(.list(.integer())));
      expect({
        for (final List<int> list in lists) ...list,
      }, hasLength(lessThan(5)));
    },
    [
      [
        [0, 1, -1, 2, -2],
      ],
    ],
  );
}
