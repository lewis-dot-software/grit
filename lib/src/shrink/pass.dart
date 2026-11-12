import '../choice/choice.dart';
import '../choice/choice_sequence.dart';

/// One way of proposing smaller sequences: a function from the current
/// sequence to its candidates, in a fixed order.
///
/// A candidate may be no smaller than the sequence it came from, as where a
/// span is zeroed that is zero already.
enum Pass {
  /// Each span of 8, 4, 3, 2 or 1 choices deleted, the widest first and each
  /// width from the end back, each deletion followed by the same with the
  /// choice before the span lowered by 1, where that choice is above 0.
  ///
  /// The lowered choice is one such as a length, read before the span it
  /// counts.
  deleteSpan,

  /// Each span of 8, 4, 3, 2 or 1 choices set to 0, the spans in the order
  /// [deleteSpan] takes them.
  zeroSpan,

  /// Each choice, from the first, lowered to the values a binary search for
  /// its smallest failing value probes where every probe passes, over pairs
  /// of choices: 0 first, then both choices of the pair halfway from the
  /// last pair probed to the choice's own, and last the other choice of its
  /// own pair, where that is below it.
  lowerChoice,

  /// Each two choices 8, 4, 3, 2 or 1 apart, the farthest apart first,
  /// lowered by the same amount: the smaller of the two to the values
  /// [lowerChoice] probes, and the other by as much.
  lowerTogether,

  /// Each span of 8, 4, 3 or 2 choices sorted, then each two choices 8, 4, 3
  /// or 2 apart swapped, each from the end back.
  reorder,

  /// Value moved from each choice to the one 8, 4, 3, 2 or 1 places after
  /// it, the earlier lowered as [lowerChoice] lowers it and the later raised
  /// by as much, then by 1 less where more than 1 moved, each where that
  /// stays within [Choice.largest].
  ///
  /// The raise by 1 less moves value to an integer counted on along one side
  /// of its zigzag, where one choice is one value and not two.
  moveValue;

  /// The candidates this pass proposes from [sequence], in order, from the
  /// one at [from] on.
  ///
  /// The candidates before [from] are passed over unbuilt.
  Iterable<ChoiceSequence> candidates(
    ChoiceSequence sequence, {
    int from = 0,
  }) => switch (this) {
    deleteSpan => _deleteSpans(sequence.choices),
    zeroSpan => _zeroSpans(sequence.choices),
    lowerChoice => _lowerChoices(sequence.choices),
    lowerTogether => _lowerTogether(sequence.choices),
    reorder => _reorder(sequence.choices),
    moveValue => _moveValue(sequence.choices),
  }.skip(from).map((_Build build) => build());
}

/// A candidate not yet built, so passing over it costs nothing of its
/// length.
typedef _Build = ChoiceSequence Function();

/// The widths of span the passes take, the widest first.
const List<int> _widths = [8, 4, 3, 2, 1];

/// Each start of a span of [width] within [length] choices, from the end
/// back.
Iterable<int> _startsBack(int length, int width) sync* {
  for (int start = length - width; start >= 0; start--) {
    yield start;
  }
}

Iterable<_Build> _deleteSpans(List<Choice> choices) sync* {
  for (final int width in _widths) {
    for (final int start in _startsBack(choices.length, width)) {
      yield () =>
          .new([...choices.take(start), ...choices.skip(start + width)]);
      if (start > 0 && choices[start - 1].value > 0) {
        yield () => .new([
          ...choices.take(start - 1),
          .new(choices[start - 1].value - 1),
          ...choices.skip(start + width),
        ]);
      }
    }
  }
}

Iterable<_Build> _zeroSpans(List<Choice> choices) sync* {
  for (final int width in _widths) {
    for (final int start in _startsBack(choices.length, width)) {
      yield () => .new([
        ...choices.take(start),
        for (int i = 0; i < width; i++) .new(0),
        ...choices.skip(start + width),
      ]);
    }
  }
}

Iterable<_Build> _lowerChoices(List<Choice> choices) sync* {
  for (int i = 0; i < choices.length; i++) {
    for (final int lowered in _probes(choices[i].value)) {
      yield () => _replaced(choices, {i: .new(lowered)});
    }
  }
}

Iterable<_Build> _lowerTogether(List<Choice> choices) sync* {
  for (final int apart in _widths) {
    for (int i = 0; i + apart < choices.length; i++) {
      final int j = i + apart;
      final int first = choices[i].value;
      final int second = choices[j].value;
      final int smaller = first < second ? first : second;
      for (final int lowered in _probes(smaller)) {
        final int by = smaller - lowered;
        yield () =>
            _replaced(choices, {i: .new(first - by), j: .new(second - by)});
      }
    }
  }
}

Iterable<_Build> _reorder(List<Choice> choices) sync* {
  for (final int width in _widths.where((int width) => width > 1)) {
    for (final int start in _startsBack(choices.length, width)) {
      yield () => .new([
        ...choices.take(start),
        ...choices.sublist(start, start + width)
          ..sort((Choice a, Choice b) => a.value.compareTo(b.value)),
        ...choices.skip(start + width),
      ]);
    }
  }
  for (final int apart in _widths.where((int width) => width > 1)) {
    for (final int i in _startsBack(choices.length, apart + 1)) {
      final int j = i + apart;
      yield () => _replaced(choices, {i: choices[j], j: choices[i]});
    }
  }
}

Iterable<_Build> _moveValue(List<Choice> choices) sync* {
  for (final int apart in _widths) {
    for (int i = 0; i + apart < choices.length; i++) {
      final int j = i + apart;
      final int from = choices[i].value;
      final int to = choices[j].value;
      for (final int lowered in _probes(from)) {
        final int moved = from - lowered;
        for (final int raised in [moved, if (moved > 1) moved - 1]) {
          if (raised > Choice.largest.value - to) continue;
          yield () =>
              _replaced(choices, {i: .new(lowered), j: .new(to + raised)});
        }
      }
    }
  }
}

/// The values below [value] a binary search for the smallest failing value
/// probes where every probe passes, over the pairs of choices an integer's
/// zigzag puts at one distance from the value it shrinks towards: 1 and 2,
/// 3 and 4, and on.
///
/// It probes 0, then both choices of the pair halfway from just above the
/// last pair probed to [value]'s own, and last the other choice of [value]'s
/// pair where that is below it. A search over single choices would probe one
/// side of the zigzag alone, and never lower a value on the other.
Iterable<int> _probes(int value) sync* {
  if (value == 0) return;
  final int pair = (value + 1) >> 1;
  yield 0;
  for (int low = 1; low < pair;) {
    final int middle = low + (pair - low) ~/ 2;
    yield 2 * middle - 1;
    yield 2 * middle;
    low = middle + 1;
  }
  if (value.isEven) yield value - 1;
}

/// [choices] with each place [replacements] names holding its choice.
ChoiceSequence _replaced(List<Choice> choices, Map<int, Choice> replacements) =>
    .new([
      for (int i = 0; i < choices.length; i++) replacements[i] ?? choices[i],
    ]);
