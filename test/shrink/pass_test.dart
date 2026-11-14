import 'package:grit/grit.dart';
import 'package:grit/src/choice/choice_source.dart';
import 'package:grit/src/choice/span.dart';
import 'package:grit/src/gen/gen.dart';
import 'package:grit/src/shrink/pass.dart';
import 'package:test/test.dart';

import '../support/drawing.dart';
import '../support/small.dart';

/// The candidates [pass] proposes from [values], whose run made [spans],
/// from the one at [from] on, each as its values.
List<List<int>> _candidates(
  Pass pass,
  List<int> values, {
  List<Span> spans = const [],
  int from = 0,
}) => [
  for (final ChoiceSequence candidate in pass.candidates(
    sequenceOf(values),
    spans,
    from: from,
  ))
    [for (final Choice choice in candidate.choices) choice.value],
];

/// Nine choices, from 9 down to 1.
final List<int> _nineDown = [for (int i = 9; i >= 1; i--) i];

/// Five choices drawn as one draw holding two, the first of which holds one
/// draw of its own:
///
/// - The whole, from 0, 5 wide.
/// - `[1, 2]`, from 1, holding `[2]`.
/// - `[3, 4]`, from 3.
final List<Span> _nested = [
  (start: 0, width: 5, depth: 0),
  (start: 1, width: 2, depth: 1),
  (start: 2, width: 1, depth: 2),
  (start: 3, width: 2, depth: 1),
];

/// A list of lists of integers, so its elements' spans differ in width.
final Gen<List<List<int>>> _lists = .list(.list(.integer(min: 0, max: 9)));

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

  test('deleting and lowering lowers each two choices by 1, the farthest '
      'apart first, each with each span just before the first deleted, the '
      'widest first', () {
    expect(_candidates(.deleteAndLower, [5, 1, 2, 3]), [
      [0, 2, 2],
      [0, 1, 3],
      [1, 2],
      [5, 1, 2],
    ]);
  });

  test('deleting and lowering proposes nothing for a pair holding a 0, nor '
      'for a pair with no choice before it', () {
    expect(_candidates(.deleteAndLower, [3, 0, 4]), isEmpty);
    expect(_candidates(.deleteAndLower, [2, 3]), isEmpty);
  });

  test('deleting and lowering deletes an element before two indices into '
      'the list, so each still indexes the element it did', () {
    // The list [0, 2, 1], each element behind a "one more" choice: deleting
    // its first element leaves 2 and 1 indexing each other as 1 and 0.
    expect(
      _candidates(.deleteAndLower, [1, 0, 1, 2, 1, 1, 0]),
      contains(equals([1, 1, 1, 0, 0])),
    );
  });

  test('lowering and copying lowers each choice to the values lowering a '
      'choice probes, each with each later 0 set to the choice after it', () {
    expect(_candidates(.lowerAndCopy, [2, 0, 3, 0, 1]), [
      [0, 3, 3, 0, 1],
      [0, 0, 3, 1, 1],
      [1, 3, 3, 0, 1],
      [1, 0, 3, 1, 1],
      [2, 0, 0, 1, 1],
      [2, 0, 1, 1, 1],
      [2, 0, 2, 1, 1],
    ]);
  });

  test('lowering and copying reaches a 0 8 choices after the lowered choice '
      'and no farther', () {
    final List<int> seven = .filled(7, 5);
    expect(
      _candidates(.lowerAndCopy, [1, ...seven, 0, 2]),
      contains(equals([0, ...seven, 2, 2])),
    );
    expect(
      _candidates(.lowerAndCopy, [
        1,
        ...seven,
        5,
        0,
        2,
      ]).where((List<int> candidate) => candidate.first == 0),
      isEmpty,
    );
  });

  test(
    'deleting and raising deletes each span, the widest first and each '
    'width from the end back, with the choice after it raised by its sum',
    () {
      expect(_candidates(.deleteAndRaise, [2, 0, 1, 3]), [
        [6],
        [2, 4],
        [3, 3],
        [2, 0, 4],
        [2, 1, 3],
      ]);
    },
  );

  test('deleting and raising proposes nothing for a span of 0s, nor where '
      'the raise passes the largest', () {
    expect(_candidates(.deleteAndRaise, [0, 0, 5]), isEmpty);
    expect(_candidates(.deleteAndRaise, [1, Choice.largest.value]), isEmpty);
    expect(_candidates(.deleteAndRaise, [1, Choice.largest.value - 1]), [
      [Choice.largest.value],
    ]);
  });

  test('deleting and raising folds an element of a list into the positive '
      'integer after it', () {
    // The list [3, 4] of integers from -10 to 10, each element behind a "one
    // more" choice: 3, 4 and 7 are the choices 5, 7 and 13.
    expect(
      _candidates(.deleteAndRaise, [1, 5, 1, 7, 0]),
      contains(equals([1, 13, 0])),
    );
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

  test('lifting a span puts each span beneath a draw in its place, each draw '
      'from the first', () {
    expect(_candidates(.liftSpan, [7, 1, 2, 3, 4], spans: _nested), [
      [1, 2],
      [2],
      [3, 4],
      [7, 2, 3, 4],
    ]);
  });

  test('swapping spans swaps two draws with the same draw around both, '
      'whatever their widths', () {
    expect(_candidates(.swapSpan, [7, 1, 2, 3, 4], spans: _nested), [
      [7, 3, 4, 1, 2],
    ]);
  });

  test("swapping spans swaps two draws of the property's body", () {
    final List<Span> spans = [
      (start: 0, width: 1, depth: 0),
      (start: 1, width: 2, depth: 0),
      (start: 3, width: 1, depth: 0),
    ];
    expect(_candidates(.swapSpan, [5, 1, 2, 3], spans: spans), [
      [1, 2, 5, 3],
      [3, 1, 2, 5],
      [5, 3, 1, 2],
    ]);
  });

  test('a pass over spans proposes nothing from a run that made none', () {
    for (final Pass pass in [.liftSpan, .swapSpan]) {
      expect(_candidates(pass, _nineDown), isEmpty, reason: pass.name);
    }
  });

  property(
    "Swapping two sibling spans in a list's record draws the list with those "
    'two elements swapped.',
    (Draw draw) {
      final ChoiceSource source = .random(
        .new(draw(.integer(min: 0), label: 'seed')),
        limit: 1000,
      );
      final RunDraw run = .new(source);
      final List<List<int>> list = run(_lists);
      draw.assume(list.length >= 2);
      final int i = draw(.integer(min: 0, max: list.length - 2), label: 'i');
      final int j = draw(
        .integer(min: i + 1, max: list.length - 1),
        label: 'j',
      );
      final List<List<int>> swapped = [...list];
      swapped[i] = list[j];
      swapped[j] = list[i];
      expect([
        for (final ChoiceSequence candidate in Pass.swapSpan.candidates(
          source.record,
          run.spans,
        ))
          if (drawFrom(_lists, candidate) case Drew(
            :final List<List<int>> value,
          ))
            value,
      ], contains(equals(swapped)));
    },
  );

  test('a pass from a place proposes the candidates from that place on', () {
    expect(_candidates(.deleteSpan, [1, 2, 3], from: 4), [
      [1, 2],
      [1, 1],
      [1, 3],
      [0, 3],
      [2, 3],
    ]);
    // Three draws of three choices each, each holding a draw of its first.
    final List<Span> spans = [
      for (int start = 0; start < 9; start += 3) ...[
        (start: start, width: 3, depth: 0),
        (start: start, width: 1, depth: 1),
      ],
    ];
    // Nine choices down from 9 with a 0 after each odd one, so every pass
    // proposes some.
    final List<int> choices = [9, 0, 7, 0, 5, 0, 3, 0, 1];
    for (final Pass pass in Pass.values) {
      final List<List<int>> all = _candidates(pass, choices, spans: spans);
      expect(all, isNotEmpty, reason: pass.name);
      for (int from = 0; from <= all.length + 1; from++) {
        expect(
          _candidates(pass, choices, spans: spans, from: from),
          all.skip(from),
          reason: '${pass.name} from $from',
        );
      }
    }
  });

  test('every pass proposes nothing from the empty sequence', () {
    for (final Pass pass in Pass.values) {
      expect(_candidates(pass, []), isEmpty, reason: pass.name);
    }
  });
}
