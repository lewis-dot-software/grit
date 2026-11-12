import '../choice/choice.dart';
import '../choice/choice_sequence.dart';

/// One way of proposing smaller sequences: a function from the current
/// sequence to its candidates, in a fixed order.
///
/// A candidate may be no smaller than the sequence it came from, as where a
/// span is zeroed that is zero already.
enum Pass {
  /// Each span of 8, 4, 2 or 1 choices deleted, the widest first and each
  /// width from the end back.
  deleteSpan,

  /// Each span of 8, 4, 2 or 1 choices set to 0, in the order [deleteSpan]
  /// takes.
  zeroSpan,

  /// Each choice, from the first, lowered to the values a binary search for
  /// its smallest failing value probes where every probe passes: 0 first,
  /// then halfway from the last probe to the choice.
  lowerChoice,

  /// Each span of 8, 4 or 2 choices sorted, then each two choices 8, 4 or 2
  /// apart swapped, each from the end back.
  reorder,

  /// Value moved from each choice to the one 8, 4, 2 or 1 places after it,
  /// the earlier lowered as [lowerChoice] lowers it and the later raised by
  /// as much, where that stays within [Choice.largest].
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
    reorder => _reorder(sequence.choices),
    moveValue => _moveValue(sequence.choices),
  }.skip(from).map((_Build build) => build());
}

/// A candidate not yet built, so passing over it costs nothing of its
/// length.
typedef _Build = ChoiceSequence Function();

/// The widths of span the passes take, the widest first.
const List<int> _widths = [8, 4, 2, 1];

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
        if (moved > Choice.largest.value - to) continue;
        yield () => _replaced(choices, {i: .new(lowered), j: .new(to + moved)});
      }
    }
  }
}

/// The values below [value] a binary search for the smallest failing value
/// probes where every probe passes: 0, then halfway from just above the last
/// probe to [value].
Iterable<int> _probes(int value) sync* {
  if (value == 0) return;
  yield 0;
  for (int low = 1; low < value;) {
    final int middle = low + (value - low) ~/ 2;
    yield middle;
    low = middle + 1;
  }
}

/// [choices] with each place [replacements] names holding its choice.
ChoiceSequence _replaced(List<Choice> choices, Map<int, Choice> replacements) =>
    .new([
      for (int i = 0; i < choices.length; i++) replacements[i] ?? choices[i],
    ]);
