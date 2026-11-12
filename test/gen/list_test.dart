import 'package:grit/grit.dart';
import 'package:grit/src/choice/status.dart';
import 'package:test/test.dart';

import '../support/drawing.dart';
import '../support/generator.dart';
import '../support/small.dart';

/// Elements whose every choice is 0 or 1, so a sequence of bits draws a list
/// of them wherever it starts, unless a list among them at its maximum
/// length reads a 1 where only 0 ends it.
final List<Generator> _bitElements = [
  .new('a boolean', .boolean()),
  .new('an integer from 0 to 1', .integer(min: 0, max: 1)),
  .new('an integer from -1 to 0', .integer(min: -1, max: 0)),
  .new('an element of a and b', .element(['a', 'b'])),
  .new('a list of booleans', .list(.boolean())),
  .new(
    'a list of booleans from 1 to 2 long',
    .list(.boolean(), minLength: 1, maxLength: 2),
  ),
  .new('a list of lists of booleans', .list(.list(.boolean()))),
];

/// A bit, 1 twice as often as 0, so a list read from bits runs past its
/// minimum length more often than not.
final Gen<int> _bit = .element([0, 1, 1]);

/// More zeros than any list of [_bitElements] reads to its end, wherever the
/// bits before them stop.
final List<int> _ending = .filled(64, 0);

/// The span of [record] that holds each element of a list of [element]'s
/// values at least [minLength] long, each from its "one more" choice to the
/// element's last choice, found by drawing each element alone from where it
/// starts.
List<(int, int)> _spans<E>(
  Gen<E> element,
  ChoiceSequence record, {
  required int minLength,
}) {
  final List<Choice> choices = record.choices;
  final List<(int, int)> spans = [];
  int at = 0;
  while (spans.length < minLength || choices[at].value == 1) {
    final ChoiceSequence rest = .new(choices.skip(at + 1));
    final int end = at + 1 + drawFrom(element, rest).record.choices.length;
    spans.add((at, end));
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
  final List<(int, int)> spans = _spans(element, record, minLength: minLength);
  expect(spans, hasLength(drew.value.length), reason: '$reason: $record');
  for (int i = 0; i < spans.length; i++) {
    final (int start, int end) = spans[i];
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
    final List<(String, Gen<Object?>, Gen<List<Object?>>, int, int, int)>
    lists = [
      ('a list of integers', digit, .list(digit), 0, 8, 2),
      ('a list of lists', bits, .list(bits), 0, 9, 1),
      (
        'a list with a minimum length',
        digit,
        .list(digit, minLength: 1),
        1,
        8,
        2,
      ),
      (
        'a list with a longer minimum length',
        digit,
        .list(digit, minLength: 2),
        2,
        8,
        2,
      ),
      (
        'a list with a maximum length',
        digit,
        .list(digit, maxLength: 2),
        0,
        8,
        2,
      ),
    ];
    for (final (
          String name,
          Gen<Object?> element,
          Gen<List<Object?>> gen,
          int minLength,
          int size,
          int bound,
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
    for (final (int first, int second) in [(0, 0), (0, 1), (1, 0), (1, 1)]) {
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
    property('Deleting one element\'s span from a list\'s record draws the '
        'same list with that element removed.', (Draw draw) {
      final Generator element = draw(.element(_bitElements), label: 'element');
      final int minLength = draw(
        .integer(min: 0, max: 4),
        label: 'minimum length',
      );
      final int? maxLength = draw(.boolean())
          ? draw(
              .integer(min: minLength, max: minLength + 8),
              label: 'maximum length',
            )
          : null;
      final Gen<List<Object?>> gen = .list(
        element.gen,
        minLength: minLength,
        maxLength: maxLength,
      );
      // Runs of bits flattened, so a record reaches dozens of choices where
      // one list's averages a handful.
      final List<int> bits = draw(
        .list(.list(_bit)).map(
          (List<List<int>> runs) => [
            for (final List<int> bits in runs) ...bits,
          ],
        ),
        label: 'bits',
      );
      final Drawing<List<Object?>> drawing = drawFrom(
        gen,
        sequenceOf([...bits, ..._ending]),
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
