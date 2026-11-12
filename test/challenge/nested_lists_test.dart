import 'package:grit/grit.dart';
import 'package:test/test.dart';

import '../support/challenge.dart';

/// A list of lists of zeros, under the false property that their lengths sum
/// to at most 10.
void main() {
  challenge(
    'nested lists',
    (Draw draw) {
      final List<List<int>> lists = draw(
        .list(.list(.integer(min: 0, max: 0))),
      );
      expect(
        lists.fold(0, (int sum, List<int> list) => sum + list.length),
        lessThanOrEqualTo(10),
      );
    },
    [
      [List.filled(11, 0)],
    ],
  );
}
