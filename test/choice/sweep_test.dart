import 'package:grit/grit.dart';
import 'package:grit/src/choice/sweep.dart';
import 'package:test/test.dart';

import '../support/small.dart';

void main() {
  test('gives a choice each edge it names in turn, then none', () {
    final Sweep sweep = .new();
    final ChoiceSequence edges = sequenceOf([3, 1, 2]);
    expect(
      [
        for (int i = 0; i < 5; i++)
          sweep.next((bound: .new(9), edges: edges), alike: 0),
      ],
      [Choice(3), Choice(1), Choice(2), null, null],
    );
  });

  test('gives none to a choice that names none', () {
    expect(
      Sweep().next((bound: .new(9), edges: sequenceOf([])), alike: 0),
      isNull,
    );
  });

  test('tells a choice from another by its bound, its edges and its place '
      'among the choices alike before it', () {
    final Sweep sweep = .new();
    final ChoiceSequence edges = sequenceOf([3, 1]);
    expect(sweep.next((bound: .new(9), edges: edges), alike: 0), Choice(3));
    expect(sweep.next((bound: .new(8), edges: edges), alike: 0), Choice(3));
    expect(
      sweep.next((bound: .new(9), edges: sequenceOf([3, 2])), alike: 0),
      Choice(3),
    );
    expect(sweep.next((bound: .new(9), edges: edges), alike: 1), Choice(3));
    expect(
      sweep.next((bound: .new(9), edges: sequenceOf([3, 1])), alike: 0),
      Choice(1),
    );
  });
}
