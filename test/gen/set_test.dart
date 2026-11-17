import 'package:grit/grit.dart';
import 'package:grit/src/choice/status.dart';
import 'package:test/test.dart';

import '../support/bits.dart';
import '../support/bounds.dart';
import '../support/draw_from.dart';
import '../support/drawing.dart';
import '../support/generator.dart';
import '../support/integer_range.dart';
import '../support/long_end.dart';
import '../support/small.dart';

/// Each minimum and maximum size checked, a null maximum for none.
final List<Bounds> _sizes = [
  (min: 0, max: null),
  (min: 1, max: null),
  (min: 2, max: null),
  (min: 0, max: 1),
  (min: 1, max: 2),
  (min: 2, max: 3),
];

/// One element a set kept, with its span.
///
/// - `start`: where its "one more" choice sits in the record.
/// - `end`: where the draw it was kept from ends, past any draws before it
///   that repeated another element.
/// - `value`: the element.
typedef _Kept = ({int start, int end, Object? value});

/// One draw of an element, kept or repeating one the set held.
///
/// - `start`: where in the record the draw starts.
/// - `value`: the value it drew.
typedef _Draw = ({int start, Object? value});

/// What a set's record holds.
///
/// - `kept`: each element the set kept, with its span, in order.
/// - `draws`: every draw of an element, in order, kept or not.
typedef _Reading = ({List<_Kept> kept, List<_Draw> draws});

/// What the [record] a set of [element]'s values from [minSize] to [maxSize]
/// in size read holds, found by drawing each element alone from where it
/// starts.
_Reading _read(
  Gen<Object?> element,
  ChoiceSequence record, {
  required int minSize,
  required int? maxSize,
}) {
  final List<Choice> choices = record.choices;
  final List<_Kept> kept = [];
  final List<_Draw> draws = [];
  final Set<Object?> seen = {};
  int at = 0;
  while (kept.length != maxSize) {
    final int start = at;
    final bool more = kept.length < minSize || choices[at].value == 1;
    at++;
    if (!more) break;
    bool added = false;
    for (int i = 0; i < 3 && !added; i++) {
      final Drawing<Object?> drawing = drawFrom(
        element,
        .new(choices.skip(at)),
      );
      final Object? value = (drawing as Drew<Object?>).value;
      draws.add((start: at, value: value));
      at += drawing.record.choices.length;
      added = seen.add(value);
      if (added) kept.add((start: start, end: at, value: value));
    }
    if (!added) break;
  }
  return (kept: kept, draws: draws);
}

/// Checks that deleting the span of each element of the set [drew] read,
/// where no later draw repeats it, draws from [gen] the same set without
/// that element, and counts the deletions.
int _expectEachDeletion(
  Gen<Set<Object?>> gen,
  Gen<Object?> element,
  Drew<Set<Object?>> drew, {
  required int minSize,
  required int? maxSize,
  String? reason,
}) {
  final ChoiceSequence record = drew.record;
  final (:List<_Kept> kept, :List<_Draw> draws) = _read(
    element,
    record,
    minSize: minSize,
    maxSize: maxSize,
  );
  expect(
    [for (final _Kept k in kept) k.value],
    drew.value.toList(),
    reason: '$reason: $record',
  );
  int deleted = 0;
  for (int i = 0; i < kept.length; i++) {
    final (:int start, :int end, :Object? value) = kept[i];
    if (draws.any((_Draw d) => d.start >= end && d.value == value)) continue;
    final ChoiceSequence shorter = .new([
      ...record.choices.take(start),
      ...record.choices.skip(end),
    ]);
    final String deleting = '$reason: $record less $start to $end';
    final Drawing<Set<Object?>> drawing = drawFrom(gen, shorter);
    expect(drawing, isA<Drew<Set<Object?>>>(), reason: deleting);
    expect(
      (drawing as Drew<Set<Object?>>).value.toList(),
      drew.value.toList()..removeAt(i),
      reason: deleting,
    );
    expect(drawing.record, shorter, reason: deleting);
    deleted++;
  }
  return deleted;
}

/// A set checked over larger inputs.
///
/// - `element`: one of [bitElements].
/// - `sizes`: its minimum and maximum size.
/// - `sequence`: bits that end in zeros, for it to draw from.
typedef _BitSet = ({Generator element, Bounds sizes, ChoiceSequence sequence});

/// A set of one of [bitElements], with bits to draw it from.
final Gen<_BitSet> _bitSet = .build(
  (Draw draw) => (
    element: draw(.element(bitElements), label: 'element'),
    sizes: draw(bounds, label: 'sizes'),
    sequence: sequenceOf([...draw(bitRuns, label: 'bits'), ...zeros]),
  ),
);

void main() {
  final Gen<int> digit = .integer(min: 0, max: 2);

  test('Every set drawn holds from its minimum to its maximum elements.', () {
    for (final (min: int minSize, max: int? maxSize) in _sizes) {
      final Gen<Set<int>> gen = .set(digit, minSize: minSize, maxSize: maxSize);
      int drawn = 0;
      for (final ChoiceSequence sequence in everySequence(
        length: 8,
        bound: 2,
      )) {
        if (drawFrom(gen, sequence) case Drew(:final Set<int> value)) {
          expect(
            value.length,
            inInclusiveRange(minSize, maxSize ?? 3),
            reason: '$minSize to $maxSize: $sequence',
          );
          drawn++;
        }
      }
      expect(drawn, greaterThan(0), reason: '$minSize to $maxSize');
    }
  });

  test('Deleting one element\'s span from the record of a set larger than '
      'its minimum, where no later draw repeats that element, draws the set '
      'without that element.', () {
    for (final (min: int minSize, max: int? maxSize) in _sizes) {
      final Gen<Set<Object?>> gen = .set(
        digit,
        minSize: minSize,
        maxSize: maxSize,
      );
      int deleted = 0;
      for (final ChoiceSequence sequence in everySequence(
        length: 9,
        bound: 2,
      )) {
        if (drawFrom(gen, sequence) case final Drew<Set<Object?>> drew
            when drew.value.length > minSize) {
          deleted += _expectEachDeletion(
            gen,
            digit,
            drew,
            minSize: minSize,
            maxSize: maxSize,
            reason: '$minSize to $maxSize',
          );
        }
      }
      // The check proves nothing where no sequence draws an element to
      // delete.
      expect(deleted, greaterThan(100), reason: '$minSize to $maxSize');
    }
  });

  test('draws again where a draw repeats an element the set holds', () {
    final Drawing<Set<int>> drawing = drawFrom(
      .set(.integer(min: 0, max: 9)),
      sequenceOf([1, 4, 1, 4, 7, 0]),
    );
    expect((drawing as Drew<Set<int>>).value, {4, 7});
    expect(drawing.record, sequenceOf([1, 4, 1, 4, 7, 0]));
  });

  test('ends where it stands once three draws repeat, at or past its '
      'minimum size', () {
    final Drawing<Set<int>> drawing = drawFrom(
      .set(.integer(min: 0, max: 9), minSize: 1),
      sequenceOf([1, 4, 1, 4, 4, 4, 1, 7]),
    );
    expect((drawing as Drew<Set<int>>).value, {4});
    expect(drawing.record, sequenceOf([1, 4, 1, 4, 4, 4]));
  });

  test('rejects the run once three draws repeat, under its minimum size', () {
    final Drawing<Set<int>> drawing = drawFrom(
      .set(.integer(min: 0, max: 9), minSize: 2),
      sequenceOf([1, 4, 1, 4, 4, 4, 1, 7]),
    );
    expect((drawing as Stopped<Set<int>>).status, Status.rejected);
    expect(drawing.record, sequenceOf([1, 4, 1, 4, 4, 4]));
  });

  test('rejects the run on all-zero choices at a minimum size of 2 or '
      'more', () {
    for (int minSize = 2; minSize <= 4; minSize++) {
      expect(
        (drawFrom(
          .set(.integer(min: 0, max: 9), minSize: minSize),
          sequenceOf(zeros),
        ) as Stopped<Set<int>>).status,
        Status.rejected,
        reason: 'minimum size $minSize',
      );
    }
  });

  test('ends at its maximum size on a choice that can only be 0', () {
    final Gen<Set<int>> gen = .set(.integer(min: 0, max: 9), maxSize: 2);
    final Drawing<Set<int>> full = drawFrom(gen, sequenceOf([1, 4, 1, 7, 0]));
    expect((full as Drew<Set<int>>).value, {4, 7});
    expect(full.record, sequenceOf([1, 4, 1, 7, 0]));
    expect(
      (drawFrom(gen, sequenceOf([1, 4, 1, 7, 1])) as Stopped<Set<int>>).status,
      Status.rejected,
    );
  });

  test('reaches the last quarter of its size range in a fair share of runs, '
      'from a narrow range and a wide one', () {
    for (final IntegerRange range in sizeRanges) {
      final Gen<Set<int>> gen = .set(
        .integer(min: 0, max: 1 << 40),
        minSize: range.min,
        maxSize: range.max,
      );
      expect(
        longEndRuns(gen, range, (Set<int> set) => set.length),
        greaterThan(10),
        reason: '$range',
      );
    }
  });

  group('a consumer\'s mistake', () {
    test('a negative minimum size is thrown', () {
      expect(() => Gen.set(.boolean(), minSize: -1), throwsRangeError);
    });

    test('a minimum size above the maximum is thrown', () {
      expect(
        () => Gen.set(.boolean(), minSize: 2, maxSize: 1),
        throwsArgumentError,
      );
    });
  });

  group('on grit, over larger inputs', () {
    property('Every set drawn holds from its minimum to its maximum '
        'elements.', (Draw draw) {
      final (
        :Generator element,
        sizes: (min: int minSize, max: int? maxSize),
        sequence: ChoiceSequence s,
      ) = draw(
        _bitSet,
        label: 'set',
      );
      final Drawing<Set<Object?>> drawing = drawFrom(
        .set(element.gen, minSize: minSize, maxSize: maxSize),
        s,
      );
      if (drawing case Drew(:final Set<Object?> value)) {
        expect(
          value.length,
          inInclusiveRange(minSize, maxSize ?? Choice.largest.value),
        );
      }
    });

    property('Deleting one element\'s span from the record of a set larger '
        'than its minimum, where no later draw repeats that element, draws '
        'the set without that element.', (Draw draw) {
      final (
        :Generator element,
        sizes: (min: int minSize, max: int? maxSize),
        sequence: ChoiceSequence s,
      ) = draw(
        _bitSet,
        label: 'set',
      );
      final Gen<Set<Object?>> gen = .set(
        element.gen,
        minSize: minSize,
        maxSize: maxSize,
      );
      final Drawing<Set<Object?>> drawing = drawFrom(gen, s);
      // A set at its minimum size has no smaller set to draw.
      draw.assume(
        drawing is Drew<Set<Object?>> && drawing.value.length > minSize,
      );
      _expectEachDeletion(
        gen,
        element.gen,
        drawing as Drew<Set<Object?>>,
        minSize: minSize,
        maxSize: maxSize,
      );
    });
  });
}
