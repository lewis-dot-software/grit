import 'package:grit/grit.dart';
import 'package:test/test.dart';

import '../support/inputs.dart';
import '../support/small.dart';

/// Whether [a] and [b] hold the same choices, told with no appeal to the
/// order.
bool _sameChoices(ChoiceSequence a, ChoiceSequence b) =>
    a.choices.length == b.choices.length &&
    [for (int i = 0; i < a.choices.length; i++) i]
        .every((int i) => a.choices[i] == b.choices[i]);

void main() {
  group('shortlex', () {
    test('a shorter sequence is smaller, whatever its choices', () {
      expect(sequenceOf([9, 9]).isSmallerThan(sequenceOf([0, 0, 0])), isTrue);
      expect(sequenceOf([0, 0, 0]).isSmallerThan(sequenceOf([9, 9])), isFalse);
    });

    test('a sequence of one length is smaller at its first difference', () {
      expect(
        sequenceOf([1, 0, 9]).isSmallerThan(sequenceOf([1, 1, 0])),
        isTrue,
      );
      expect(
        sequenceOf([1, 1, 0]).isSmallerThan(sequenceOf([1, 0, 9])),
        isFalse,
      );
    });

    test('a sequence is never smaller than itself', () {
      expect(sequenceOf([2, 1]).isSmallerThan(sequenceOf([2, 1])), isFalse);
      expect(sequenceOf([2, 1]).compareTo(sequenceOf([2, 1])), 0);
    });

    test('the empty sequence is smaller than every other', () {
      expect(sequenceOf([]).isSmallerThan(sequenceOf([0])), isTrue);
      expect(sequenceOf([]).choices, isEmpty);
    });

    test('sorting puts sequences in shortlex order', () {
      final List<ChoiceSequence> sorted = [
        sequenceOf([0, 1]),
        sequenceOf([3]),
        sequenceOf([]),
        sequenceOf([0, 0]),
        sequenceOf([1, 0]),
      ]..sort();
      expect(sorted, [
        sequenceOf([]),
        sequenceOf([3]),
        sequenceOf([0, 0]),
        sequenceOf([0, 1]),
        sequenceOf([1, 0]),
      ]);
    });

    test('every sequence is smaller than each one enumerated after it', () {
      final List<ChoiceSequence> sequences = everySequence(
        length: 3,
        bound: 2,
      ).toList();
      for (int i = 0; i < sequences.length; i++) {
        for (int j = i + 1; j < sequences.length; j++) {
          expect(
            sequences[i].isSmallerThan(sequences[j]),
            isTrue,
            reason: '${sequences[i]} and ${sequences[j]}',
          );
        }
      }
    });
  });

  group('equality', () {
    test('sequences of the same choices are equal and hash alike', () {
      expect(sequenceOf([1, 2]), sequenceOf([1, 2]));
      expect(sequenceOf([1, 2]).hashCode, sequenceOf([1, 2]).hashCode);
    });

    test('sequences of different choices are unequal', () {
      expect(sequenceOf([1, 2]), isNot(sequenceOf([2, 1])));
      expect(sequenceOf([1]), isNot(sequenceOf([1, 0])));
    });
  });

  test('a sequence keeps its choices from later changes to its source', () {
    final List<Choice> source = [.new(1)];
    final ChoiceSequence sequence = .new(source);
    source.add(.new(2));
    expect(sequence, sequenceOf([1]));
    expect(() => sequence.choices.add(.new(3)), throwsUnsupportedError);
  });

  test('a sequence prints as its choices', () {
    expect(sequenceOf([0, 4]).toString(), '[0, 4]');
  });

  test('a negative choice is a bug, thrown', () {
    expect(() => Choice(-1), throwsRangeError);
  });

  group('over every small sequence', () {
    test(
      'For any two different sequences, exactly one is shortlex smaller than '
      'the other.',
      () {
        final List<ChoiceSequence> sequences = everySequence(
          length: 4,
          bound: 3,
        ).toList();
        // The enumeration yields each sequence once, so two places hold two
        // different sequences, told apart with no appeal to the order.
        for (int i = 0; i < sequences.length; i++) {
          for (int j = 0; j < sequences.length; j++) {
            if (i == j) continue;
            final ChoiceSequence a = sequences[i];
            final ChoiceSequence b = sequences[j];
            expect(
              a.isSmallerThan(b) != b.isSmallerThan(a),
              isTrue,
              reason: '$a and $b',
            );
          }
        }
      },
    );
  });

  group('on grit, over larger inputs', () {
    property('For any two different sequences, exactly one is shortlex '
        'smaller than the other.', (Draw draw) {
      // The two share a prefix, so they differ at a later choice as often as
      // by their lengths.
      final List<Choice> prefix = draw(.list(anyChoice), label: 'prefix');
      final ChoiceSequence a = .new([
        ...prefix,
        ...draw(.list(anyChoice), label: 'a after it'),
      ]);
      final ChoiceSequence b = .new([
        ...prefix,
        ...draw(.list(anyChoice), label: 'b after it'),
      ]);
      draw.assume(!_sameChoices(a, b));
      expect(a.isSmallerThan(b) != b.isSmallerThan(a), isTrue);
    });
  });
}
