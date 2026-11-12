import 'package:grit/src/choice/choice.dart';
import 'package:grit/src/choice/choice_sequence.dart';
import 'package:grit/src/choice/status.dart';
import 'package:grit/src/gen/gen.dart';
import 'package:test/test.dart';

import '../support/drawing.dart';
import '../support/small.dart';

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
          final List<(int, int)> spans = _spans(
            element,
            record,
            minLength: minLength,
          );
          expect(spans, hasLength(list.length), reason: '$record');
          if (list.length == minLength) continue;
          for (int i = 0; i < spans.length; i++) {
            final (int start, int end) = spans[i];
            final ChoiceSequence shorter = .new([
              ...record.choices.take(start),
              ...record.choices.skip(end),
            ]);
            final Drawing<List<Object?>> drawing = drawFrom(gen, shorter);
            final String reason = '$name: $record less $start to $end';
            expect(drawing, isA<Drew<List<Object?>>>(), reason: reason);
            expect(
              (drawing as Drew<List<Object?>>).value,
              [...list]..removeAt(i),
              reason: reason,
            );
            expect(drawing.record, shorter, reason: reason);
            deleted++;
          }
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
}
