import 'dart:math';

import 'package:grit/grit.dart';
import 'package:test/test.dart';

import '../support/challenge.dart';

/// A list whose length is drawn first, from 1 to 100, then its elements, each
/// from 0 to 1000, under the false property that every element is below 900.
void main() {
  challenge(
    'length list',
    (Draw draw) {
      final List<int> list = draw(
        .build((Draw draw) {
          final int length = draw(.integer(min: 1, max: 100));
          return [
            for (int i = 0; i < length; i++) draw(.integer(min: 0, max: 1000)),
          ];
        }),
      );
      expect(list.reduce(max), lessThan(900));
    },
    [
      [900],
    ],
  );
}
