import 'package:grit/grit.dart';
import 'package:test/test.dart';

import '../support/challenge.dart';

/// Reversing a list, under the false property that the reverse of any list
/// is the list itself.
void main() {
  challenge(
    'reverse',
    (Draw draw) {
      final List<int> list = draw(.list(.integer()));
      expect(list.reversed, list);
    },
    [
      [0, 1],
    ],
  );
}
