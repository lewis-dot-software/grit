import 'package:grit/src/choice/choice_sequence.dart';
import 'package:grit/src/choice/choice_source.dart';
import 'package:grit/src/choice/status.dart';
import 'package:grit/src/gen/gen.dart';
import 'package:test/test.dart';

import '../support/drawing.dart';
import '../support/small.dart';

/// The largest choice and length the exhaustive checks reach.
const int _bound = 3;
const int _length = 5;

/// Generators of every kind the stage has, each built on the others, so a
/// property checked over them is checked over each.
final Map<String, Gen<Object?>> _generators = {
  'an integer': .integer(),
  'a narrow integer': .integer(min: -2, max: 1),
  'a boolean': .boolean(),
  'an element': .element(['a', 'b', 'c']),
  'a list': .list(.integer(min: 0, max: 2)),
  'a bounded list': .list(.boolean(), minLength: 1, maxLength: 2),
  'a list of lists': .list(.list(.boolean())),
  'a mapped generator': .integer(min: 0, max: 3).map((int i) => i * 10),
  'a filtered generator': .integer(min: 0, max: 3).filter((int i) => i.isEven),
  'a built generator': .build((Draw draw) {
    final int length = draw(.integer(min: 0, max: 2));
    return [for (int i = 0; i < length; i++) draw(.boolean())];
  }),
};

void main() {
  group('every generator', () {
    test('Each of `.integer`, `.boolean`, `.list` and `.element` draws its '
        'documented simplest value from all-zero choices.', () {
      final ChoiceSequence zeros = sequenceOf(.filled(64, 0));
      final List<(String, Gen<Object?>, Object?)> cases = [
        for (int min = -4; min <= 4; min++)
          for (int max = min; max <= 4; max++)
            (
              'an integer from $min to $max', .integer(min: min, max: max),
              // The value in range nearest 0.
              min > 0 ? min : (max < 0 ? max : 0),
            ),
        ('an integer of the default range', .integer(), 0),
        ('an integer of the widest range', .integer(min: 1 << 63, max: -1), -1),
        ('a boolean', .boolean(), false),
        ('a list', .list(.integer()), <int>[]),
        (
          'a list with a minimum length',
          .list(.integer(min: 3, max: 5), minLength: 2),
          [3, 3],
        ),
        (
          'a list of lists with a minimum length',
          .list(.list(.boolean(), minLength: 1), minLength: 2),
          [
            [false],
            [false],
          ],
        ),
        (
          'a list with a maximum length of 0',
          .list(.boolean(), maxLength: 0),
          <bool>[],
        ),
        ('an element', .element(['a', 'b', 'c']), 'a'),
        ('an element of one value', .element([7]), 7),
      ];
      for (final (String name, Gen<Object?> gen, Object? simplest) in cases) {
        final Drawing<Object?> drawing = drawFrom(gen, zeros);
        expect(drawing, isA<Drew<Object?>>(), reason: name);
        expect((drawing as Drew<Object?>).value, simplest, reason: name);
      }
    });

    test('The same sequence always draws the same value.', () {
      for (final MapEntry(key: String name, value: Gen<Object?> gen)
          in _generators.entries) {
        for (final ChoiceSequence sequence in everySequence(
          length: _length,
          bound: _bound,
        )) {
          final Drawing<Object?> first = drawFrom(gen, sequence);
          final Drawing<Object?> second = drawFrom(gen, sequence);
          final String reason = '$name from $sequence';
          expect(second.record, first.record, reason: reason);
          switch ((first, second)) {
            case (Drew(value: final Object? a), Drew(value: final Object? b)):
              expect(b, a, reason: reason);
            case (
              Stopped(status: final Status a),
              Stopped(status: final Status b),
            ):
              expect(b, a, reason: reason);
            case (Drew(), Stopped()) || (Stopped(), Drew()):
              fail('$reason drew $first, then $second');
          }
        }
      }
    });
  });

  group('Gen.build', () {
    test('draws a value that depends on one drawn before it', () {
      final Gen<(int, List<bool>)> gen = .build((Draw draw) {
        final int length = draw(.integer(min: 0, max: 3));
        return (length, draw(.list(.boolean(), minLength: length)));
      });
      final Drawing<(int, List<bool>)> drawing = drawFrom(
        gen,
        sequenceOf([3, 0, 1, 0, 0, 0, 1, 0]),
      );
      expect(drawing, isA<Drew<(int, List<bool>)>>());
      final (int length, List<bool> list) =
          (drawing as Drew<(int, List<bool>)>).value;
      expect(length, 3);
      expect(list, [true, false, true]);
    });

    test('ends the run where its body throws', () {
      final Gen<int> gen = .build((Draw draw) => throw StateError('broken'));
      expect(drawFrom(gen, .empty), isA<Stopped<int>>());
      expect((drawFrom(gen, .empty) as Stopped<int>).status, Status.failed);
    });
  });

  group('map', () {
    test('draws its conversion of the value beneath it, from the same '
        'choices', () {
      final Gen<String> gen = .integer(min: 0, max: 9).map((int i) => 'n$i');
      final Drawing<String> drawing = drawFrom(gen, sequenceOf([7]));
      expect((drawing as Drew<String>).value, 'n7');
      expect(drawing.record, sequenceOf([7]));
    });
  });

  group('filter', () {
    test('A filtered generator only ever draws a value its predicate accepts, '
        'and rejects the run once its retries are spent.', () {
      // From 0 to 3 each choice draws itself, so the expected end of each
      // draw is read off the choices alone.
      final Gen<int> gen = .integer(min: 0, max: 3).filter((int i) => i.isEven);
      final Gen<int> never = .integer(min: 0, max: 3).filter((_) => false);
      for (final ChoiceSequence sequence in everySequence(
        length: _length,
        bound: _bound,
      )) {
        final List<int> choices = [for (final c in sequence.choices) c.value];
        final int firstEven = choices
            .take(3)
            .toList()
            .indexWhere((int c) => c.isEven);
        final Drawing<int> drawing = drawFrom(gen, sequence);
        final String reason = '$sequence';
        if (drawing case Drew(:final int value)) {
          expect(value.isEven, isTrue, reason: reason);
        }
        if (firstEven != -1) {
          expect(
            (drawing as Drew<int>).value,
            choices[firstEven],
            reason: reason,
          );
          expect(
            drawing.record,
            sequenceOf(choices.take(firstEven + 1).toList()),
            reason: reason,
          );
        } else {
          expect(
            (drawing as Stopped<int>).status,
            choices.length < 3 ? Status.overrun : Status.rejected,
            reason: reason,
          );
        }
        expect(
          (drawFrom(never, sequence) as Stopped<int>).status,
          choices.length < 3 ? Status.overrun : Status.rejected,
          reason: reason,
        );
      }
    });
  });

  group('a draw', () {
    test('keeps each value the property\'s body drew, with its label, and '
        'none drawn inside a generator', () {
      final ChoiceSource source = .fixed(sequenceOf([1, 1, 2, 0]));
      final Draw draw = .new(source);
      final bool flag = draw(.boolean(), label: 'flag');
      final List<int> xs = draw(.list(.integer(min: 0, max: 3)));
      expect(flag, isTrue);
      expect(xs, [2]);
      expect(
        [for (final Drawn drawn in draw.draws) drawn.label],
        ['flag', null],
      );
      expect(
        [for (final Drawn drawn in draw.draws) drawn.value],
        [
          true,
          [2],
        ],
      );
    });

    test('keeps no value from a draw the source stopped', () {
      final ChoiceSource source = .fixed(.empty);
      final Draw draw = .new(source);
      expect(run(source, () => draw(.boolean())), Status.overrun);
      expect(draw.draws, isEmpty);
    });

    test('rejects the run where an assumption is false, and goes on where '
        'it is true', () {
      final ChoiceSource source = .fixed(sequenceOf([1]));
      final Draw draw = .new(source);
      expect(
        run(source, () {
          draw.assume(true);
          draw.assume(draw(.boolean()));
        }),
        Status.returned,
      );

      final ChoiceSource rejecting = .fixed(sequenceOf([0, 1]));
      final Draw rejected = .new(rejecting);
      expect(
        run(rejecting, () {
          rejected.assume(rejected(.boolean()));
          rejected(.boolean());
        }),
        Status.rejected,
      );
      expect(rejecting.record, sequenceOf([0]));
    });

    test('keeps each line noted, in order, from the body and from inside a '
        'generator', () {
      final ChoiceSource source = .fixed(sequenceOf([1]));
      final Draw draw = .new(source);
      draw.note('first');
      draw(
        .build((Draw inner) {
          inner.note('inside');
          return inner(.boolean());
        }),
      );
      draw.note('last');
      expect(draw.notes, ['first', 'inside', 'last']);
    });

    test('names a generator by dot shorthand where one is expected', () {
      final ChoiceSource source = .fixed(sequenceOf([1, 3, 0]));
      final Draw draw = .new(source);
      final List<int> xs = draw(.list(.integer()));
      expect(xs, [2]);
    });
  });
}
