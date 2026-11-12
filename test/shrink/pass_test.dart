import 'package:grit/src/choice/choice.dart';
import 'package:grit/src/choice/choice_sequence.dart';
import 'package:grit/src/shrink/pass.dart';
import 'package:test/test.dart';

import '../support/small.dart';

/// The candidates [pass] proposes from [values] from the one at [from] on,
/// each as its values.
List<List<int>> _candidates(Pass pass, List<int> values, {int from = 0}) => [
  for (final ChoiceSequence candidate in pass.candidates(
    sequenceOf(values),
    from: from,
  ))
    [for (final Choice choice in candidate.choices) choice.value],
];

/// Nine choices, from 9 down to 1.
final List<int> _nineDown = [for (int i = 9; i >= 1; i--) i];

void main() {
  test('deleting a span deletes each span, the widest first and each width '
      'from the end back, each deletion followed by the same with the choice '
      'before the span lowered by 1', () {
    expect(_candidates(.deleteSpan, [1, 2, 3]), [
      <int>[],
      [1],
      [0],
      [3],
      [1, 2],
      [1, 1],
      [1, 3],
      [0, 3],
      [2, 3],
    ]);
  });

  test('deleting a span never lowers a choice of 0 before it', () {
    expect(_candidates(.deleteSpan, [0, 5]), [
      <int>[],
      [0],
      [5],
    ]);
  });

  test('deleting a span with the choice before it lowered deletes an element '
      'a length counts', () {
    // A length of 3 then three elements, the first two of them 0: the
    // deletion of an element passes alone, since the length still reads
    // three.
    expect(_candidates(.deleteSpan, [3, 0, 0, 7]), contains(equals([2, 0, 7])));
  });

  test('deleting a span reaches spans of 8, 4 and 3', () {
    final List<int> nine = [for (int i = 1; i <= 9; i++) i];
    final List<List<int>> candidates = _candidates(.deleteSpan, nine);
    expect(candidates.take(3), [
      [1],
      [0],
      [9],
    ]);
    expect(candidates.skip(3).first, [1, 2, 3, 4, 5]);
    expect(candidates, contains(equals([1, 2, 3, 4, 5, 6])));
  });

  test('zeroing a span zeroes each span in the order deleting takes its '
      'spans', () {
    expect(_candidates(.zeroSpan, [1, 2, 3]), [
      [0, 0, 0],
      [1, 0, 0],
      [0, 0, 3],
      [1, 2, 0],
      [1, 0, 3],
      [0, 2, 3],
    ]);
  });

  test('lowering a choice probes 0, then each pair halfway up from the last, '
      'for each choice from the first', () {
    expect(_candidates(.lowerChoice, [9, 0, 2]), [
      [0, 0, 2],
      [5, 0, 2],
      [6, 0, 2],
      [7, 0, 2],
      [8, 0, 2],
      [9, 0, 0],
      [9, 0, 1],
    ]);
  });

  test('lowering a choice probes as a binary search over pairs of choices '
      'does where every probe passes', () {
    expect(_candidates(.lowerChoice, [100]), [
      [0],
      [49],
      [50],
      [75],
      [76],
      [87],
      [88],
      [93],
      [94],
      [97],
      [98],
      [99],
    ]);
  });

  test('lowering the largest choice probes halfway up as for any other, '
      'with no overflow past it', () {
    expect(_candidates(.lowerChoice, [Choice.largest.value]).take(3), [
      [0],
      [0x3FFFFFFFFFFFFFFF],
      [0x4000000000000000],
    ]);
  });

  test('lowering a choice probes both choices of each pair, so an integer '
      'lowers on either side of the value it shrinks towards', () {
    expect(_candidates(.lowerChoice, [4]), [
      [0],
      [1],
      [2],
      [3],
    ]);
    // A choice of 1022 is -511 by an integer's zigzag, and every choice of
    // the other parity is a positive integer.
    expect(_candidates(.lowerChoice, [1022]), contains(equals([512])));
  });

  test('lowering together lowers each two choices by the same amount, the '
      'smaller to the values lowering a choice probes, the farthest apart '
      'first', () {
    expect(_candidates(.lowerTogether, [3, 1, 2]), [
      [1, 1, 0],
      [2, 1, 1],
      [2, 0, 2],
      [3, 0, 1],
    ]);
  });

  test('lowering together proposes nothing for a pair holding a 0', () {
    expect(_candidates(.lowerTogether, [0, 5]), isEmpty);
  });

  test('reordering sorts each span, then swaps each two choices 2 or more '
      'apart', () {
    expect(_candidates(.reorder, [3, 2, 1]), [
      [1, 2, 3],
      [3, 1, 2],
      [2, 3, 1],
      [1, 2, 3],
    ]);
  });

  test('moving value lowers one choice and raises the one after it by as '
      'much, then by 1 less, the farthest apart first', () {
    expect(_candidates(.moveValue, [2, 0, 1]), [
      [0, 0, 3],
      [0, 0, 2],
      [1, 0, 2],
      [0, 2, 1],
      [0, 1, 1],
      [1, 1, 1],
    ]);
  });

  test('moving value never raises a choice past the largest', () {
    expect(_candidates(.moveValue, [1, Choice.largest.value]), isEmpty);
    expect(_candidates(.moveValue, [2, Choice.largest.value - 1]), [
      [0, Choice.largest.value],
      [1, Choice.largest.value],
    ]);
  });

  test('zeroing, sorting, swapping and moving value reach spans and '
      'distances of 8', () {
    expect(_candidates(.zeroSpan, _nineDown).first, [9, ...List.filled(8, 0)]);
    final List<List<int>> reordered = _candidates(.reorder, _nineDown);
    expect(reordered.first, [9, 1, 2, 3, 4, 5, 6, 7, 8]);
    // Sorting proposes 2 spans of 8, 6 of 4, 7 of 3 and 8 of 2 before the
    // swaps.
    expect(reordered[23], [1, 8, 7, 6, 5, 4, 3, 2, 9]);
    final List<int> moved = [0, 8, 7, 6, 5, 4, 3, 2, 10];
    expect(_candidates(.moveValue, _nineDown).first, moved);
  });

  test('a pass from a place proposes the candidates from that place on', () {
    expect(_candidates(.deleteSpan, [1, 2, 3], from: 4), [
      [1, 2],
      [1, 1],
      [1, 3],
      [0, 3],
      [2, 3],
    ]);
    for (final Pass pass in Pass.values) {
      final List<List<int>> all = _candidates(pass, _nineDown);
      for (int from = 0; from <= all.length + 1; from++) {
        expect(
          _candidates(pass, _nineDown, from: from),
          all.skip(from),
          reason: '${pass.name} from $from',
        );
      }
    }
  });

  test('every pass proposes nothing from the empty sequence', () {
    for (final Pass pass in Pass.values) {
      expect(pass.candidates(sequenceOf([])), isEmpty, reason: pass.name);
    }
  });
}
