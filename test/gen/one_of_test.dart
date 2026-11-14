import 'package:grit/grit.dart';
import 'package:grit/src/choice/status.dart';
import 'package:test/test.dart';

import '../support/bits.dart';
import '../support/drawing.dart';
import '../support/generator.dart';
import '../support/generators.dart';
import '../support/inputs.dart';
import '../support/small.dart';

/// What drawing one of [generators] from [sequence] comes to, read off
/// drawing the generator its first choice names from the choices after it.
Drawing<Object?> _chosen(
  List<Gen<Object?>> generators,
  ChoiceSequence sequence,
) {
  final List<Choice> choices = sequence.choices;
  if (choices.isEmpty) return Stopped(.overrun, sequence);
  final int index = choices.first.value;
  // A choice past its bound stops the run before it is recorded.
  if (index >= generators.length) return Stopped(.rejected, sequenceOf([]));
  final ChoiceSequence first = .new(choices.take(1));
  final ChoiceSequence rest = .new(choices.skip(1));
  return switch (drawFrom(generators[index], rest)) {
    Drew(:final Object? value, :final ChoiceSequence record) => Drew(
      value,
      .new([...first.choices, ...record.choices]),
    ),
    Stopped(:final Status status, :final ChoiceSequence record) => Stopped(
      status,
      .new([...first.choices, ...record.choices]),
    ),
  };
}

void main() {
  test('Every value `oneOf` draws is one of its generators\' values, and '
      'choices of 0 draw its first generator\'s simplest.', () {
    final List<({List<Gen<Object?>> generators, Object? simplest})> cases = [
      (generators: [.integer(min: 3, max: 5)], simplest: 3),
      (generators: [.boolean(), .integer(min: 0, max: 2)], simplest: false),
      (
        generators: [
          .list(.integer(min: 1, max: 2), minLength: 1),
          .boolean(),
          .element(['a', 'b']),
        ],
        simplest: [1],
      ),
    ];
    for (final (:List<Gen<Object?>> generators, :Object? simplest) in cases) {
      final Gen<Object?> gen = .oneOf(generators);
      for (final ChoiceSequence sequence in everySequence(
        length: 5,
        bound: 3,
      )) {
        expectAlike(
          drawFrom(gen, sequence),
          _chosen(generators, sequence),
          reason: '$generators from $sequence',
        );
      }
      expect(
        (drawFrom(gen, sequenceOf(zeros)) as Drew<Object?>).value,
        simplest,
      );
    }
  });

  test('rejects a choice past its last generator', () {
    expect(
      (drawFrom(
        .oneOf([.boolean(), .boolean()]),
        sequenceOf([2, 0]),
      ) as Stopped<bool>).status,
      Status.rejected,
    );
  });

  test('draws as it did once the generators it was given change', () {
    final List<Gen<int>> generators = [
      .integer(min: 0, max: 0),
      .integer(min: 1, max: 1),
    ];
    final Gen<int> gen = .oneOf(generators);
    generators.clear();
    expect((drawFrom(gen, sequenceOf([1, 0])) as Drew<int>).value, 1);
  });

  test('a consumer\'s mistake of no generators is thrown', () {
    expect(() => Gen.oneOf(<Gen<int>>[]), throwsArgumentError);
  });

  group('on grit, over larger inputs', () {
    property('Every value `oneOf` draws is one of its generators\' values, '
        'and choices of 0 draw its first generator\'s simplest.', (Draw draw) {
      final List<Generator> generators = draw(
        .list(anyGenerator, minLength: 1, maxLength: 4),
        label: 'generators',
      );
      final List<Gen<Object?>> gens = [
        for (final Generator generator in generators) generator.gen,
      ];
      final ChoiceSequence sequence = draw(
        smallOrAnySequence,
        label: 'sequence',
      );
      expectAlike(drawFrom(.oneOf(gens), sequence), _chosen(gens, sequence));

      final List<Simple> simple = draw(
        .list(simpleGenerator, minLength: 1, maxLength: 4),
        label: 'simple generators',
      );
      final Drawing<Object?> simplest = drawFrom(
        .oneOf([for (final Simple s in simple) s.generator.gen]),
        sequenceOf(zeros),
      );
      expect((simplest as Drew<Object?>).value, simple.first.simplest);
    });
  });
}
