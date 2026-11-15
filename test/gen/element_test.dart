import 'package:grit/src/choice/status.dart';
import 'package:grit/src/gen/gen.dart';
import 'package:test/test.dart';

import '../support/draw_from.dart';
import '../support/drawing.dart';
import '../support/small.dart';

void main() {
  test('draws the value at each choice\'s index, and rejects a choice past '
      'its last', () {
    final Gen<String> gen = .element(['a', 'b', 'c']);
    expect(
      [
        for (int choice = 0; choice <= 2; choice++)
          (drawFrom(gen, sequenceOf([choice])) as Drew<String>).value,
      ],
      ['a', 'b', 'c'],
    );
    expect(
      (drawFrom(gen, sequenceOf([3])) as Stopped<String>).status,
      Status.rejected,
    );
  });

  test('draws as it did once the values it was given change', () {
    final List<int> values = [1, 2];
    final Gen<int> gen = .element(values);
    values
      ..clear()
      ..add(9);
    expect((drawFrom(gen, sequenceOf([1])) as Drew<int>).value, 2);
  });

  test('a consumer\'s mistake of no values is thrown', () {
    expect(() => Gen.element(<int>[]), throwsArgumentError);
  });
}
