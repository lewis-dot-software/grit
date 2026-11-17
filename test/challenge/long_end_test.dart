import 'package:grit/grit.dart';
import 'package:test/test.dart';

import '../support/challenge.dart';

/// A list up to 40 long of elements from 0 to 1000, under the false property
/// that every list is shorter than 30.
void main() {
  challenge('long end', (Draw draw) {
    final List<int> list = draw(
      .list(.integer(min: 0, max: 1000), maxLength: 40),
    );
    expect(list.length, lessThan(30));
  }, [List<int>.filled(30, 0)]);
}
