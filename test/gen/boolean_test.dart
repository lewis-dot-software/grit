import 'package:grit/src/choice/status.dart';
import 'package:grit/src/gen/gen.dart';
import 'package:test/test.dart';

import '../support/drawing.dart';
import '../support/small.dart';

void main() {
  test('draws false at 0 and true at 1, and rejects a choice above 1', () {
    final Gen<bool> gen = .boolean();
    expect((drawFrom(gen, sequenceOf([0])) as Drew<bool>).value, isFalse);
    expect((drawFrom(gen, sequenceOf([1])) as Drew<bool>).value, isTrue);
    expect(
      (drawFrom(gen, sequenceOf([2])) as Stopped<bool>).status,
      Status.rejected,
    );
  });
}
