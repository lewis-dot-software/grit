import 'package:grit/grit.dart';
import 'package:grit/src/choice/choice_source.dart';
import 'package:grit/src/choice/status.dart';
import 'package:grit/src/gen/gen.dart';
import 'package:test/test.dart';

import '../support/any_generator.dart';
import '../support/bits.dart';
import '../support/exactly.dart';
import '../support/draw_from.dart';
import '../support/drawing.dart';
import '../support/expect_alike.dart';
import '../support/generator.dart';
import '../support/inputs.dart';
import '../support/predicate.dart';
import '../support/simple_generator.dart';
import '../support/small.dart';

/// The largest choice the exhaustive checks reach.
const int _bound = 3;

/// The longest sequence the exhaustive checks reach.
const int _length = 5;

/// A generator with the simplest value its docs give it:
///
/// - `name`: the generator, as a check names it.
/// - `gen`: the generator.
/// - `simplest`: its simplest value.
typedef _Simplest = ({String name, Gen<Object?> gen, Object? simplest});

/// A count drawn first, and a list at least that long drawn after it:
///
/// - `length`: the count.
/// - `list`: the list.
typedef _Counted = ({int length, List<bool> list});

/// What filtering [gen] by [accepts] draws from [sequence], read off drawing
/// [gen] alone up to three times, each from where the one before it ended.
Drawing<Object?> _filtered(
  Gen<Object?> gen,
  bool Function(Object? value) accepts,
  ChoiceSequence sequence,
) {
  ChoiceSequence upTo(int length) => .new(sequence.choices.take(length));
  int at = 0;
  for (int i = 0; i < 3; i++) {
    switch (drawFrom(gen, .new(sequence.choices.skip(at)))) {
      case Stopped(:final Status status, :final ChoiceSequence record):
        return Stopped(status, upTo(at + record.choices.length));
      case Drew(:final Object? value, :final ChoiceSequence record):
        at += record.choices.length;
        if (accepts(value)) return Drew(value, upTo(at));
    }
  }
  return Stopped(.rejected, upTo(at));
}

/// Generators of every kind grit has, each built on the others, so a
/// property checked over them is checked over each.
final Map<String, Gen<Object?>> _generators = {
  'an integer': .integer(),
  'a narrow integer': .integer(min: -2, max: 1),
  'a boolean': .boolean(),
  'an element': .element(['a', 'b', 'c']),
  'a list': .list(.integer(min: 0, max: 2)),
  'a bounded list': .list(.boolean(), minLength: 1, maxLength: 2),
  'a list of lists': .list(.list(.boolean())),
  'a string': .string(alphabet: .of('ab')),
  'a bounded string': .string(alphabet: .digits, minLength: 1, maxLength: 2),
  'one of a few generators': .oneOf([.boolean(), .integer(min: 0, max: 2)]),
  'a set': .set(.integer(min: 0, max: 2)),
  'a bounded set': .set(.boolean(), minSize: 1, maxSize: 2),
  // NaN equals nothing by `==`, nor by `equals` in a `matcher` before
  // 0.12.18, which `test`'s floor admits, so a float drawing it would never
  // draw alike there.
  'a float': .float(nan: false),
  'a bounded float': .float(min: -1.5, max: 2.5),
  'a mapped generator': .integer(min: 0, max: 3).map((int i) => i * 10),
  'a filtered generator': .integer(min: 0, max: 3).filter((int i) => i.isEven),
  'a built generator': .build((Draw draw) {
    final int length = draw(.integer(min: 0, max: 2));
    return [for (int i = 0; i < length; i++) draw(.boolean())];
  }),
};

void main() {
  group('every generator', () {
    test('Each of `.integer`, `.boolean`, `.list`, `.element`, `.string`, '
        '`.oneOf`, `.set` and `.float` draws its documented simplest value '
        'from all-zero choices.', () {
      final List<_Simplest> cases = [
        for (int min = -4; min <= 4; min++)
          for (int max = min; max <= 4; max++)
            (
              name: 'an integer from $min to $max',
              gen: .integer(min: min, max: max),
              // The value in range nearest 0.
              simplest: min > 0 ? min : (max < 0 ? max : 0),
            ),
        (name: 'an integer of the default range', gen: .integer(), simplest: 0),
        (
          name: 'an integer of the widest range',
          gen: .integer(min: 1 << 63, max: -1),
          simplest: -1,
        ),
        (name: 'a boolean', gen: .boolean(), simplest: false),
        (name: 'a list', gen: .list(.integer()), simplest: <int>[]),
        (
          name: 'a list with a minimum length',
          gen: .list(.integer(min: 3, max: 5), minLength: 2),
          simplest: [3, 3],
        ),
        (
          name: 'a list of lists with a minimum length',
          gen: .list(.list(.boolean(), minLength: 1), minLength: 2),
          simplest: [
            [false],
            [false],
          ],
        ),
        (
          name: 'a list with a maximum length of 0',
          gen: .list(.boolean(), maxLength: 0),
          simplest: <bool>[],
        ),
        (name: 'an element', gen: .element(['a', 'b', 'c']), simplest: 'a'),
        (name: 'an element of one value', gen: .element([7]), simplest: 7),
        (name: 'a string', gen: .string(), simplest: ''),
        (
          name: 'a string with a minimum length',
          gen: .string(minLength: 2),
          simplest: '00',
        ),
        (
          name: 'a string of letters with a minimum length',
          gen: .string(alphabet: .letters, minLength: 3),
          simplest: 'AAA',
        ),
        (
          name: 'a string of a string\'s characters',
          gen: .string(alphabet: .of('xyz'), minLength: 1),
          simplest: 'x',
        ),
        (
          name: 'one of a few generators',
          gen: .oneOf([.integer(min: 3, max: 5), .boolean()]),
          simplest: 3,
        ),
        (name: 'a set', gen: .set(.integer()), simplest: <int>{}),
        (
          name: 'a set with a minimum size of 1',
          gen: .set(.integer(min: 3, max: 5), minSize: 1),
          simplest: {3},
        ),
        (
          name: 'a set with a maximum size of 0',
          gen: .set(.boolean(), maxSize: 0),
          simplest: <bool>{},
        ),
        (name: 'a float', gen: .float(), simplest: 0.0),
        (
          name: 'a float above 0',
          gen: .float(min: 0.5, max: 3.25),
          simplest: 1.0,
        ),
        (
          name: 'a float of fractions alone',
          gen: .float(min: 0.25, max: 0.75),
          simplest: 0.25,
        ),
        (
          name: 'a float below 0',
          gen: .float(min: -3.25, max: -0.5),
          simplest: -1.0,
        ),
        (
          name: 'a float up to -0.0',
          gen: .float(min: -1, max: -0.0),
          simplest: -0.0,
        ),
        (
          name: 'a list of floats up to -0.0',
          gen: .list(.float(min: -0.0, max: -0.0), minLength: 1),
          simplest: [-0.0],
        ),
        (
          name: 'a float of infinities alone',
          gen: .float(min: .infinity),
          simplest: double.infinity,
        ),
      ];
      for (final (:String name, :Gen<Object?> gen, :Object? simplest)
          in cases) {
        final Drawing<Object?> drawing = drawFrom(gen, sequenceOf(zeros));
        expect(drawing, isA<Drew<Object?>>(), reason: name);
        expect(
          (drawing as Drew<Object?>).value,
          exactly(simplest),
          reason: name,
        );
      }
    });

    test('The same sequence always draws the same value.', () {
      for (final MapEntry(key: String name, value: Gen<Object?> gen)
          in _generators.entries) {
        for (final ChoiceSequence sequence in everySequence(
          length: _length,
          bound: _bound,
        )) {
          expectAlike(
            drawFrom(gen, sequence),
            drawFrom(gen, sequence),
            reason: '$name from $sequence',
          );
        }
      }
    });
  });

  group('Gen.build', () {
    test('draws a value that depends on one drawn before it', () {
      final Gen<_Counted> gen = .build((Draw draw) {
        final int length = draw(.integer(min: 0, max: 3));
        return (
          length: length,
          list: draw(.list(.boolean(), minLength: length)),
        );
      });
      final Drawing<_Counted> drawing = drawFrom(
        gen,
        sequenceOf([3, 0, 1, 0, 0, 0, 1, 0]),
      );
      expect(drawing, isA<Drew<_Counted>>());
      final (:int length, :List<bool> list) = (drawing as Drew<_Counted>).value;
      expect(length, 3);
      expect(list, [true, false, true]);
    });

    test('ends the run failed, with its error, where its body throws', () {
      final Gen<int> gen = .build((Draw draw) => throw StateError('broken'));
      final ChoiceSource source = .fixed(sequenceOf([]));
      expect(run(source, () => RunDraw(source)(gen)), Status.failed);
      expect(() => drawFrom(gen, sequenceOf([])), throwsStateError);
    });

    test('ends the run as the source stopped it where its body catches the '
        'stop and returns', () {
      final Gen<int> gen = .build((Draw draw) {
        try {
          return draw(.integer());
        } on Object {
          return 0;
        }
      });
      final Drawing<int> drawing = drawFrom(gen, sequenceOf([]));
      expect((drawing as Stopped<int>).status, Status.overrun);
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
      final RunDraw draw = .new(source);
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

    test('keeps each value\'s text as the draw returned it, whatever the '
        'body does to the value after', () {
      final ChoiceSource source = .fixed(sequenceOf([1, 0, 1, 1, 0]));
      final RunDraw draw = .new(source);
      final List<int> xs = draw(.list(.integer(min: 0, max: 1)));
      expect(xs, [0, 1]);
      xs
        ..sort((int a, int b) => b.compareTo(a))
        ..add(99);
      expect(draw.draws.single.text, '[0, 1]');
      expect(draw.draws.single.value, same(xs));
    });

    test('keeps no value from a draw the source stopped', () {
      final ChoiceSource source = .fixed(sequenceOf([]));
      final RunDraw draw = .new(source);
      expect(run(source, () => draw(.boolean())), Status.overrun);
      expect(draw.draws, isEmpty);
    });

    test('rejects the run where an assumption is false, and goes on where '
        'it is true', () {
      final ChoiceSource source = .fixed(sequenceOf([1]));
      final RunDraw draw = .new(source);
      expect(
        run(source, () {
          draw.assume(true);
          draw.assume(draw(.boolean()));
        }),
        Status.returned,
      );

      final ChoiceSource rejecting = .fixed(sequenceOf([0, 1]));
      final RunDraw rejected = .new(rejecting);
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
      final RunDraw draw = .new(source);
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

    test('keeps the value one of a few generators drew, never the generator '
        'it chose', () {
      final ChoiceSource source = .fixed(sequenceOf([1, 2]));
      final RunDraw draw = .new(source);
      final int value = draw(
        .oneOf([.integer(min: 0, max: 9), .integer(min: 10, max: 19)]),
      );
      expect(value, 12);
      expect([for (final Drawn drawn in draw.draws) drawn.value], [12]);
    });

    test('keeps the span of each draw, the property\'s body\'s and those '
        'inside a generator, in the order the draws began, with the draws in '
        'progress around each', () {
      final ChoiceSource source = .fixed(sequenceOf([1, 1, 2, 0]));
      final RunDraw draw = .new(source);
      draw(.boolean());
      draw(.list(.integer(min: 0, max: 3)));
      expect(draw.spans, [
        (start: 0, width: 1, depth: 0, form: null),
        (start: 1, width: 3, depth: 0, form: null),
        (start: 2, width: 1, depth: 1, form: null),
      ]);
    });

    test('keeps a form on the span of the draw that named it alone, never on '
        'the draw around it', () {
      final ChoiceSource source = .fixed(sequenceOf([1, 0, 3, 0]));
      final RunDraw draw = .new(source);
      expect(draw(.list(.float(min: 0.5, max: 3.25))), [0.5]);
      expect(draw.spans, [
        (start: 0, width: 4, depth: 0, form: null),
        (start: 1, width: 2, depth: 1, form: sequenceOf([0, 0])),
      ]);
    });

    test('keeps the span of a draw the source stopped, as far as it read', () {
      final ChoiceSource source = .fixed(sequenceOf([1, 1]));
      final RunDraw draw = .new(source);
      expect(
        run(source, () => draw(.list(.integer(min: 0, max: 3)))),
        Status.overrun,
      );
      expect(draw.spans, [
        (start: 0, width: 2, depth: 0, form: null),
        (start: 1, width: 1, depth: 1, form: null),
      ]);
    });

    test('names a generator by dot shorthand where one is expected', () {
      final ChoiceSource source = .fixed(sequenceOf([1, 3, 0]));
      final RunDraw draw = .new(source);
      final List<int> xs = draw(.list(.integer()));
      expect(xs, [2]);
    });
  });

  group('on grit, over larger inputs', () {
    property('Each of `.integer`, `.boolean`, `.list`, `.element`, '
        '`.string`, `.oneOf`, `.set` and `.float` draws its documented '
        'simplest value from all-zero choices.', (Draw draw) {
      final Simple simple = draw(simpleGenerator, label: 'generator');
      final Drawing<Object?> drawing = drawFrom(
        simple.generator.gen,
        sequenceOf(zeros),
      );
      expect(drawing, isA<Drew<Object?>>());
      expect((drawing as Drew<Object?>).value, exactly(simple.simplest));
    });

    property('The same sequence always draws the same value.', (Draw draw) {
      final Generator generator = draw(anyGenerator, label: 'generator');
      final ChoiceSequence sequence = draw(
        smallOrAnySequence,
        label: 'sequence',
      );
      expectAlike(
        drawFrom(generator.gen, sequence),
        drawFrom(generator.gen, sequence),
      );
    });

    test('A draw keeps each value\'s text as the draw returned it, '
        'whatever the body does to the value after.', () async {
      // 681 of 3000 drawn cases returned, so a seed misses this tally over
      // the default 100 runs about 1 in 10^11.
      int returned = 0;
      await forAll((Draw draw) {
        final Generator generator = draw(anyGenerator, label: 'generator');
        final ChoiceSequence sequence = draw(
          smallOrAnySequence,
          label: 'sequence',
        );
        final ChoiceSource source = .fixed(sequence);
        final RunDraw inner = .new(source);
        final Status status = run(source, () {
          switch (inner(generator.gen)) {
            case final List<Object?> list:
              list.clear();
            case final Set<Object?> set:
              set.clear();
          }
        });
        final ChoiceSource untouched = .fixed(sequence);
        final RunDraw left = .new(untouched);
        // A run that failed would leave the text unread, so a generator that
        // throws fails the check.
        expect(run(untouched, () => left(generator.gen)), status);
        expect(status, isNot(Status.failed));
        if (status != .returned) return;
        returned++;
        expect(inner.draws.single.text, left.draws.single.text);
      });
      expect(returned, greaterThan(0));
    });

    property('A filtered generator only ever draws a value its predicate '
        'accepts, and rejects the run once its retries are spent.', (
      Draw draw,
    ) {
      final Generator base = draw(anyGenerator, label: 'generator');
      final Predicate predicate = draw(
        .element(Predicate.values),
        label: 'predicate',
      );
      final ChoiceSequence sequence = draw(
        smallOrAnySequence,
        label: 'sequence',
      );
      final Drawing<Object?> drawing = drawFrom(
        base.gen.filter(predicate.accepts),
        sequence,
      );
      if (drawing case Drew(:final Object? value)) {
        expect(predicate.accepts(value), isTrue);
      }
      expectAlike(drawing, _filtered(base.gen, predicate.accepts, sequence));
    });
  });
}
