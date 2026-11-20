import 'dart:math';

import 'package:grit/grit.dart';
import 'package:grit/src/choice/choice_source.dart';
import 'package:grit/src/choice/status.dart';
import 'package:grit/src/gen/gen.dart';
import 'package:test/test.dart';

import '../support/bits.dart';
import '../support/bounds.dart';
import '../support/draw_from.dart';
import '../support/drawing.dart';
import '../support/fixed_random.dart';
import '../support/generator.dart';
import '../support/integer_range.dart';
import '../support/reach.dart';
import '../support/small.dart';

/// Elements whose every choice is 0 or 1, so a sequence of bits draws a list
/// of them wherever it starts, unless a list or a string among them at its
/// maximum length reads a 1 where only 0 ends it.
final List<Generator> _bitElements = [
  ...bitElements,
  .new('a list of booleans', .list(.boolean())),
  .new(
    'a list of booleans from 1 to 2 long',
    .list(.boolean(), minLength: 1, maxLength: 2),
  ),
  .new('a list of lists of booleans', .list(.list(.boolean()))),
];

/// Where one element of a list lies in its record:
///
/// - `start`: the index of its "one more" choice.
/// - `end`: the index past its last choice.
typedef _ElementSpan = ({int start, int end});

/// A list the deletion check runs over:
///
/// - `name`: the list, as the check names it.
/// - `element`: its element's generator.
/// - `gen`: the list's generator.
/// - `minLength`: its minimum length.
/// - `size`: the longest sequence the check draws it from.
/// - `bound`: the largest choice the check draws it from.
typedef _ListCase = ({
  String name,
  Gen<Object?> element,
  Gen<List<Object?>> gen,
  int minLength,
  int size,
  int bound,
});

/// The span of [record] that holds each element of a list of [element]'s
/// values at least [minLength] long, each from its "one more" choice to the
/// element's last choice, found by drawing each element alone from where it
/// starts.
List<_ElementSpan> _spans<E>(
  Gen<E> element,
  ChoiceSequence record, {
  required int minLength,
}) {
  final List<Choice> choices = record.choices;
  final List<_ElementSpan> spans = [];
  int at = 0;
  while (spans.length < minLength || choices[at].value == 1) {
    final ChoiceSequence rest = .new(choices.skip(at + 1));
    final int end = at + 1 + drawFrom(element, rest).record.choices.length;
    spans.add((start: at, end: end));
    at = end;
  }
  return spans;
}

/// Checks that deleting each element's span from the record [drew] read
/// draws from [gen], a list of [element]'s values at least [minLength] long,
/// the same list with that element removed.
void _expectEachDeletion<E>(
  Gen<List<E>> gen,
  Gen<E> element,
  Drew<List<E>> drew, {
  required int minLength,
  String? reason,
}) {
  final ChoiceSequence record = drew.record;
  final List<_ElementSpan> spans = _spans(
    element,
    record,
    minLength: minLength,
  );
  expect(spans, hasLength(drew.value.length), reason: '$reason: $record');
  for (int i = 0; i < spans.length; i++) {
    final (:int start, :int end) = spans[i];
    final ChoiceSequence shorter = .new([
      ...record.choices.take(start),
      ...record.choices.skip(end),
    ]);
    final String deleting = '$reason: $record less $start to $end';
    final Drawing<List<E>> drawing = drawFrom(gen, shorter);
    expect(drawing, isA<Drew<List<E>>>(), reason: deleting);
    expect(
      (drawing as Drew<List<E>>).value,
      [...drew.value]..removeAt(i),
      reason: deleting,
    );
    expect(drawing.record, shorter, reason: deleting);
  }
}

/// The choices that open a list's first two elements:
///
/// - `first`: the first's.
/// - `second`: the second's.
typedef _Pair = ({int first, int second});

void main() {
  test('Deleting one element\'s span from a list\'s record draws the same '
      'list with that element removed.', () {
    // Each list is named with its element, its minimum length, and the
    // longest and largest choices it is checked over. A list of lists has
    // choices of 0 and 1 alone, so its sequences reach further at the same
    // cost. A list at its minimum length has no shorter list to draw, so only
    // a longer one has an element to delete.
    final Gen<int> digit = .integer(min: 0, max: 2);
    final Gen<List<bool>> bits = .list(.boolean());
    final List<_ListCase> lists = [
      (
        name: 'a list of integers',
        element: digit,
        gen: .list(digit),
        minLength: 0,
        size: 8,
        bound: 2,
      ),
      (
        name: 'a list of lists',
        element: bits,
        gen: .list(bits),
        minLength: 0,
        size: 9,
        bound: 1,
      ),
      (
        name: 'a list with a minimum length',
        element: digit,
        gen: .list(digit, minLength: 1),
        minLength: 1,
        size: 8,
        bound: 2,
      ),
      (
        name: 'a list with a longer minimum length',
        element: digit,
        gen: .list(digit, minLength: 2),
        minLength: 2,
        size: 8,
        bound: 2,
      ),
      (
        name: 'a list with a maximum length',
        element: digit,
        gen: .list(digit, maxLength: 2),
        minLength: 0,
        size: 8,
        bound: 2,
      ),
    ];
    for (final (
          :String name,
          :Gen<Object?> element,
          :Gen<List<Object?>> gen,
          :int minLength,
          :int size,
          :int bound,
        )
        in lists) {
      int deleted = 0;
      for (final ChoiceSequence sequence in everySequence(
        length: size,
        bound: bound,
      )) {
        if (drawFrom(gen, sequence) case Drew(
          value: final List<Object?> list,
          :final ChoiceSequence record,
        )) {
          if (list.length == minLength) {
            expect(
              _spans(element, record, minLength: minLength),
              hasLength(list.length),
              reason: '$record',
            );
            continue;
          }
          _expectEachDeletion(
            gen,
            element,
            .new(list, record),
            minLength: minLength,
            reason: name,
          );
          deleted += list.length;
        }
      }
      // The check proves nothing where no sequence draws an element to
      // delete.
      expect(deleted, greaterThan(100), reason: name);
    }
  });

  test('draws one more element at each choice of 1, and ends at a 0', () {
    final Drawing<List<int>> drawing = drawFrom(
      .list(.integer(min: 0, max: 9)),
      sequenceOf([1, 4, 1, 7, 0, 5]),
    );
    expect((drawing as Drew<List<int>>).value, [4, 7]);
    expect(drawing.record, sequenceOf([1, 4, 1, 7, 0]));
  });

  test('draws one more element inside its minimum length at a choice of 0 '
      'or 1 alike', () {
    final Gen<List<int>> gen = .list(.integer(min: 0, max: 9), minLength: 2);
    for (final (:int first, :int second) in <_Pair>[
      (first: 0, second: 0),
      (first: 0, second: 1),
      (first: 1, second: 0),
      (first: 1, second: 1),
    ]) {
      final Drawing<List<int>> drawing = drawFrom(
        gen,
        sequenceOf([first, 4, second, 7, 1, 2, 0]),
      );
      expect((drawing as Drew<List<int>>).value, [4, 7, 2]);
    }
    expect(
      (drawFrom(gen, sequenceOf([2, 4])) as Stopped<List<int>>).status,
      Status.rejected,
    );
  });

  test('ends at its maximum length on a choice that can only be 0', () {
    final Gen<List<int>> gen = .list(.integer(min: 0, max: 9), maxLength: 2);
    final Drawing<List<int>> full = drawFrom(gen, sequenceOf([1, 4, 1, 7, 0]));
    expect((full as Drew<List<int>>).value, [4, 7]);
    expect(full.record, sequenceOf([1, 4, 1, 7, 0]));
    expect(
      (drawFrom(gen, sequenceOf([1, 4, 1, 7, 1])) as Stopped<List<int>>).status,
      Status.rejected,
    );
  });

  test('reaches its maximum length in more than one run in eight, and '
      'the last quarter of its range in more than one in five, wherever '
      'the run\'s room holds every element up to its maximum', () {
    for (final IntegerRange range in sizeRanges) {
      final Gen<List<bool>> gen = .list(
        .boolean(),
        minLength: range.min,
        maxLength: range.max,
      );
      final Reach shares = reach(gen, range, (List<bool> list) => list.length);
      expect(shares.atMax, greaterThan(1 / 8), reason: '$range');
      expect(shares.lastQuarter, greaterThan(1 / 5), reason: '$range');
    }
  });

  test('ends inside a run\'s limit of choices, never overrunning it, '
      'where its elements each cost alike and every "one more" choice is '
      'filled as one more', () {
    for (final Gen<Object?> gen in <Gen<Object?>>[
      .list(.integer(min: 0, max: 9), maxLength: 100000),
      .list(.boolean()),
      .list(.list(.integer(min: 0, max: 9), maxLength: 1000)),
      .string(alphabet: .ascii),
    ]) {
      // A draw of 0 fills every weighted choice at odds above never as 1.
      final ChoiceSource source = .random(
        FixedRandom(0, ints: .filled(8192, 0)),
        limit: 8192,
      );
      expect(run(source, () => RunDraw(source)(gen)), Status.returned);
    }
  });

  test('ends overrun where the choices run out before it ends', () {
    expect(
      (drawFrom(
        .list(.boolean()),
        sequenceOf([1, 1, 1]),
      ) as Stopped<List<bool>>).status,
      Status.overrun,
    );
  });

  group('a consumer\'s mistake', () {
    test('a negative minimum length is thrown', () {
      expect(() => Gen.list(.boolean(), minLength: -1), throwsRangeError);
    });

    test('a minimum length above the maximum is thrown', () {
      expect(
        () => Gen.list(.boolean(), minLength: 2, maxLength: 1),
        throwsArgumentError,
      );
    });
  });

  group('on grit, over larger inputs', () {
    property('A list whose elements each cost alike ends inside its run, '
        'every "one more" choice filled as one more, wherever the room it '
        'starts with fits its minimum, or one element where that is 0, and a '
        'choice more.', (Draw draw) {
      final int bits = draw(.integer(min: 0, max: 3), label: 'element bits');
      final (min: int minLength, max: int? maxLength) = draw(
        bounds,
        label: 'lengths',
      );
      // An element of a list of [bits] booleans exactly costs a "one more"
      // choice and one for each boolean before each, and a 0 that ends it,
      // beside its own "one more" choice.
      final int cost = 2 * bits + 2;
      final int spare = draw(.integer(min: 0, max: 60), label: 'spare room');
      final int limit = max(minLength, 1) * cost + 1 + spare;
      final Gen<List<List<bool>>> gen = .list(
        .list(.boolean(), minLength: bits, maxLength: bits),
        minLength: minLength,
        maxLength: maxLength,
      );
      // A draw of 0 fills every weighted choice at odds above never as 1.
      final ChoiceSource source = .random(
        FixedRandom(0, ints: .filled(limit, 0)),
        limit: limit,
      );
      expect(run(source, () => RunDraw(source)(gen)), Status.returned);
    });

    property('Deleting one element\'s span from a list\'s record draws the '
        'same list with that element removed.', (Draw draw) {
      final Generator element = draw(.element(_bitElements), label: 'element');
      final (min: int minLength, max: int? maxLength) = draw(
        bounds,
        label: 'lengths',
      );
      final Gen<List<Object?>> gen = .list(
        element.gen,
        minLength: minLength,
        maxLength: maxLength,
      );
      final List<int> bits = draw(bitRuns, label: 'bits');
      final Drawing<List<Object?>> drawing = drawFrom(
        gen,
        sequenceOf([...bits, ...zeros]),
      );
      // A list at its minimum length has no shorter list to draw.
      draw.assume(
        drawing is Drew<List<Object?>> && drawing.value.length > minLength,
      );
      _expectEachDeletion(
        gen,
        element.gen,
        drawing as Drew<List<Object?>>,
        minLength: minLength,
      );
    });
  });
}
