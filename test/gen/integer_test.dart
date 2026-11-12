import 'package:grit/src/choice/status.dart';
import 'package:grit/src/gen/gen.dart';
import 'package:test/test.dart';

import '../support/drawing.dart';
import '../support/small.dart';

/// The value [gen] draws from the one choice [choice].
int _drawn(Gen<int> gen, int choice) =>
    (drawFrom(gen, sequenceOf([choice])) as Drew<int>).value;

void main() {
  test('An integer always draws within its range, and a smaller choice never '
      'draws a value further from its target.', () {
    for (int min = -6; min <= 6; min++) {
      for (int max = min; max <= 6; max++) {
        final Gen<int> gen = .integer(min: min, max: max);
        final int target = min > 0 ? min : (max < 0 ? max : 0);
        final List<int> values = [
          for (int choice = 0; choice <= max - min; choice++)
            _drawn(gen, choice),
        ];
        final String reason = 'from $min to $max: $values';
        for (final int value in values) {
          expect(value, inInclusiveRange(min, max), reason: reason);
        }
        for (int choice = 1; choice < values.length; choice++) {
          expect(
            (values[choice - 1] - target).abs(),
            lessThanOrEqualTo((values[choice] - target).abs()),
            reason: reason,
          );
        }
      }
    }
  });

  test('draws each value of its range from exactly one choice', () {
    for (int min = -6; min <= 6; min++) {
      for (int max = min; max <= 6; max++) {
        final Gen<int> gen = .integer(min: min, max: max);
        final Set<int> values = {
          for (int choice = 0; choice <= max - min; choice++)
            _drawn(gen, choice),
        };
        expect(values, hasLength(max - min + 1), reason: '$min to $max');
      }
    }
  });

  test('rejects a choice past its range', () {
    final Drawing<int> drawing = drawFrom(
      .integer(min: -1, max: 1),
      sequenceOf([3]),
    );
    expect((drawing as Stopped<int>).status, Status.rejected);
  });

  test('draws above its target before below it, at each distance', () {
    final Gen<int> gen = .integer(min: -3, max: 3);
    expect(
      [for (int c = 0; c <= 6; c++) _drawn(gen, c)],
      [0, 1, -1, 2, -2, 3, -3],
    );
  });

  test('counts on along the longer side once the shorter runs out', () {
    expect(
      [for (int c = 0; c <= 5; c++) _drawn(.integer(min: -1, max: 4), c)],
      [0, 1, -1, 2, 3, 4],
    );
    expect(
      [for (int c = 0; c <= 5; c++) _drawn(.integer(min: -4, max: 1), c)],
      [0, 1, -1, -2, -3, -4],
    );
  });

  test('draws towards its minimum where its range lies above 0, and its '
      'maximum where it lies below', () {
    expect(
      [for (int c = 0; c <= 3; c++) _drawn(.integer(min: 5, max: 8), c)],
      [5, 6, 7, 8],
    );
    expect(
      [for (int c = 0; c <= 3; c++) _drawn(.integer(min: -8, max: -5), c)],
      [-5, -6, -7, -8],
    );
  });

  test('draws the ends of the default range, that of a 32-bit signed '
      'integer', () {
    final Gen<int> gen = .integer();
    const int largest = (1 << 32) - 1;
    expect(_drawn(gen, largest), -(1 << 31));
    expect(_drawn(gen, largest - 1), -((1 << 31) - 1));
    expect(_drawn(gen, largest - 2), (1 << 31) - 1);
    expect(
      (drawFrom(gen, sequenceOf([largest + 1])) as Stopped<int>).status,
      Status.rejected,
    );
  });

  test('draws the ends of the widest range a choice holds', () {
    const int smallest = 1 << 63;
    const int largest = -1 >>> 1;
    final Gen<int> below = .integer(min: smallest, max: -1);
    expect(_drawn(below, 0), -1);
    expect(_drawn(below, largest), smallest);
    final Gen<int> above = .integer(min: 0, max: largest);
    expect(_drawn(above, largest), largest);
    final Gen<int> across = .integer(
      min: smallest >> 1,
      max: -(smallest >> 1) - 1,
    );
    expect(_drawn(across, largest), smallest >> 1);
    expect(_drawn(across, largest - 1), (smallest >> 1) + 1);
    expect(_drawn(across, largest - 2), -(smallest >> 1) - 1);
  });

  group('a consumer\'s mistake', () {
    test('a minimum above the maximum is thrown', () {
      expect(() => Gen.integer(min: 1, max: 0), throwsArgumentError);
    });

    test('a range holding more values than a choice does is thrown', () {
      expect(() => Gen.integer(min: 1 << 63, max: 0), throwsArgumentError);
      expect(() => Gen.integer(min: -1, max: -1 >>> 1), throwsArgumentError);
    });
  });
}
