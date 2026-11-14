import '../choice/choice.dart';
import '../choice/choice_sequence.dart';
import '../choice/span.dart';

/// One way of proposing smaller sequences: a function from the current
/// sequence, and the spans its run made, to its candidates, in a fixed order.
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

  /// Each draw's span replaced by the span of each draw beneath it, the
  /// draws taken in the order they began, so a part of a value takes the
  /// place of the part it sits in.
  liftSpan,

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

  /// Each two sibling draws' spans swapped, the draws taken in the order
  /// they began: two draws with the same draw around both, or two the
  /// property's body made, so two parts of a value change places whatever
  /// their widths.
  swapSpan,

  /// Value moved from each choice to the one 8, 4, 3, 2 or 1 places after
  /// it, the earlier lowered as [lowerChoice] lowers it and the later raised
  /// by as much, then by 1 less where more than 1 moved, each where that
  /// stays within [Choice.largest].
  ///
  /// The raise by 1 less moves value to an integer counted on along one side
  /// of its zigzag, where one choice is one value and not two.
  moveValue,

  /// Each two choices 8, 4, 3, 2 or 1 apart, the farthest apart first and
  /// each from the first on, both lowered by 1, where both are above 0, each
  /// with each span of 8, 4, 3, 2 or 1 choices just before the first of them
  /// deleted, the widest first.
  ///
  /// The two lowered choices are values such as indices, which count the
  /// elements before them, so each falls by 1 as one of those is deleted.
  deleteAndLower,

  /// Each choice, from the first, lowered to the values [lowerChoice] probes,
  /// each with each 0 among the 8 choices after it set to the choice that
  /// follows the 0, where that is above 0.
  ///
  /// The 0 is a choice such as an empty branch's, so it takes the branch the
  /// draw after it took, where a value lowered before it leaves the room.
  lowerAndCopy;

  /// Whether a round takes this pass only where it has accepted nothing yet.
  ///
  /// A costly pass proposes candidates that rarely fail where a cheaper pass
  /// has not, so it waits for the cheaper passes to stall.
  bool get costly => switch (this) {
    deleteSpan ||
    liftSpan ||
    zeroSpan ||
    lowerChoice ||
    lowerTogether ||
    reorder ||
    swapSpan ||
    moveValue => false,
    deleteAndLower || lowerAndCopy => true,
  };

  /// The candidates this pass proposes from [sequence], whose run made
  /// [spans], in order, from the one at [from] on.
  ///
  /// The candidates before [from] are passed over unbuilt.
  Iterable<ChoiceSequence> candidates(
    ChoiceSequence sequence,
    List<Span> spans, {
    int from = 0,
  }) => switch (this) {
    deleteSpan => _deleteSpans(sequence.choices),
    liftSpan => _liftSpans(sequence.choices, spans),
    zeroSpan => _zeroSpans(sequence.choices),
    lowerChoice => _lowerChoices(sequence.choices),
    lowerTogether => _lowerTogether(sequence.choices),
    reorder => _reorder(sequence.choices),
    swapSpan => _swapSpans(sequence.choices, spans),
    moveValue => _moveValue(sequence.choices),
    deleteAndLower => _deleteAndLower(sequence.choices),
    lowerAndCopy => _lowerAndCopy(sequence.choices),
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

Iterable<_Build> _liftSpans(List<Choice> choices, List<Span> spans) sync* {
  for (int i = 0; i < spans.length; i++) {
    final Span outer = spans[i];
    for (int j = i + 1; j < spans.length && spans[j].depth > outer.depth; j++) {
      final Span inner = spans[j];
      yield () => .new([
        ...choices.take(outer.start),
        ..._of(choices, inner),
        ...choices.skip(outer.start + outer.width),
      ]);
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

Iterable<_Build> _swapSpans(List<Choice> choices, List<Span> spans) sync* {
  for (int i = 0; i < spans.length; i++) {
    final Span first = spans[i];
    for (
      int j = i + 1;
      j < spans.length && spans[j].depth >= first.depth;
      j++
    ) {
      final Span second = spans[j];
      if (second.depth > first.depth) continue;
      yield () => .new([
        ...choices.take(first.start),
        ..._of(choices, second),
        ...choices.sublist(first.start + first.width, second.start),
        ..._of(choices, first),
        ...choices.skip(second.start + second.width),
      ]);
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

Iterable<_Build> _deleteAndLower(List<Choice> choices) sync* {
  for (final int apart in _widths) {
    for (int i = 0; i + apart < choices.length; i++) {
      final int j = i + apart;
      if (choices[i].value == 0 || choices[j].value == 0) continue;
      for (final int width in _widths.where((int width) => width <= i)) {
        yield () => .new([
          ...choices.take(i - width),
          .new(choices[i].value - 1),
          ...choices.sublist(i + 1, j),
          .new(choices[j].value - 1),
          ...choices.skip(j + 1),
        ]);
      }
    }
  }
}

Iterable<_Build> _lowerAndCopy(List<Choice> choices) sync* {
  for (int i = 0; i < choices.length; i++) {
    for (final int lowered in _probes(choices[i].value)) {
      for (int j = i + 1; j <= i + 8 && j + 1 < choices.length; j++) {
        final Choice following = choices[j + 1];
        if (choices[j].value != 0 || following.value == 0) continue;
        yield () => _replaced(choices, {i: .new(lowered), j: following});
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
  // Half of value, rounded up, with no overflow at Choice.largest.
  final int pair = value - (value >> 1);
  yield 0;
  for (int low = 1; low < pair;) {
    final int middle = low + (pair - low) ~/ 2;
    yield 2 * middle - 1;
    yield 2 * middle;
    low = middle + 1;
  }
  if (value.isEven) yield value - 1;
}

/// The choices of [choices] that [span] holds.
List<Choice> _of(List<Choice> choices, Span span) =>
    choices.sublist(span.start, span.start + span.width);

/// [choices] with each place [replacements] names holding its choice.
ChoiceSequence _replaced(List<Choice> choices, Map<int, Choice> replacements) =>
    .new([
      for (int i = 0; i < choices.length; i++) replacements[i] ?? choices[i],
    ]);
