import '../choice/choice.dart';
import '../choice/choice_sequence.dart';
import '../choice/span.dart';

/// One way of proposing smaller sequences: a function from the current
/// sequence, and the spans its run made, to its candidates, in a fixed order.
///
/// A candidate may be no smaller than the sequence it came from, as where a
/// span is zeroed that is zero already.
enum Pass {
  /// Each span of 8, 4, 3, 2 or 1 choices that ends at the last choice
  /// deleted, the widest first, each deletion followed by the same with the
  /// choice before the span lowered by 1, where that choice is above 0.
  ///
  /// The lowered choice is one such as a "one more" choice, so a collection
  /// that ends the sequence loses its last elements at every width, in at
  /// most two candidates per width, however long the sequence.
  deleteLast,

  /// Each span of each draw of the property's body with the spans of every
  /// draw beneath it set to 0 at once, the draws taken in the order they
  /// began, where any draw is beneath it.
  ///
  /// The draws beneath are a value's parts, such as a collection's elements,
  /// so every part takes its simplest choices in one candidate, the choices
  /// the value makes between them, such as a collection's "one more"
  /// choices, kept. A draw within another proposes none, so the pass costs
  /// one candidate per draw of the body, however large its value.
  zeroBeneath,

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

  /// Each draw's span replaced by the simpler form its generator named for
  /// it, where it named one, the draws taken in the order they began, so a
  /// value takes the place of one of its kind a choice-by-choice search
  /// passes over.
  simplifySpan,

  /// Each span of 8, 4, 3, 2 or 1 choices set to 0, the widest first and each
  /// width from the end back.
  zeroSpan,

  /// Each choice, from the first, lowered to the values a binary search for
  /// its smallest failing value probes where every probe passes, over pairs
  /// of choices: 0 first, then both choices of the pair halfway from the
  /// last pair probed to the choice's own, and last the other choice of its
  /// own pair, where that is below it.
  lowerChoice,

  /// Each two choices 8, 4, 3, 2 or 1 apart, the farthest apart first,
  /// lowered by the same amount: the smaller of the two to the values
  /// [_probes] gives for it, and the other by as much.
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
  /// it, the earlier lowered to the values [_probes] gives for it and the
  /// later raised by as much, then by 1 less where more than 1 moved, each
  /// where that stays within [Choice.largest].
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

  /// Each choice, from the first, lowered to the values [_probes] gives for it,
  /// each with each 0 among the 8 choices after it set to the choice that
  /// follows the 0, where that is above 0.
  ///
  /// The 0 is a choice such as an empty branch's, so it takes the branch the
  /// draw after it took, where a value lowered before it leaves the room.
  lowerAndCopy,

  /// Each span of 8, 4, 3, 2 or 1 choices deleted, the widest first and each
  /// width from the end back, with the choice after the span raised by the
  /// span's sum, where that sum is above 0 and the raise stays within
  /// [Choice.largest].
  ///
  /// The span is a value such as a list's element, whose choices move into
  /// the value after it as it is deleted, so two values fold into one.
  deleteAndRaise;

  /// Whether a round takes this pass only where it has accepted nothing yet.
  ///
  /// A costly pass proposes candidates that rarely fail where a cheaper pass
  /// has not, or, as [moveValue] does, ones that raise a choice a cheaper
  /// pass lowered earlier in the round, so it waits for the cheaper passes to
  /// stall.
  bool get costly => switch (this) {
    deleteLast ||
    zeroBeneath ||
    deleteSpan ||
    liftSpan ||
    simplifySpan ||
    zeroSpan ||
    lowerChoice ||
    lowerTogether ||
    reorder ||
    swapSpan => false,
    moveValue || deleteAndLower || lowerAndCopy || deleteAndRaise => true,
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
    deleteLast => _deleteLast(sequence.choices),
    zeroBeneath => _zeroBeneath(sequence.choices, spans),
    deleteSpan => _deleteSpans(sequence.choices),
    liftSpan => _liftSpans(sequence.choices, spans),
    simplifySpan => _simplifySpans(sequence.choices, spans),
    zeroSpan => _zeroSpans(sequence.choices),
    lowerChoice => _lowerChoices(sequence.choices),
    lowerTogether => _lowerTogether(sequence.choices),
    reorder => _reorder(sequence.choices),
    swapSpan => _swapSpans(sequence.choices, spans),
    moveValue => _pairs(
      sequence.choices.length,
    ).expand((_Pair pair) => _moveValue(sequence.choices, pair)),
    deleteAndLower => _deleteAndLower(sequence.choices),
    lowerAndCopy => _lowerAndCopy(sequence.choices),
    deleteAndRaise => _deleteAndRaise(sequence.choices),
  }.skip(from).map((_Build build) => build());

  /// The place among the candidates this pass proposes from [next] to go on
  /// from, where its candidate at [position] among those it proposes from
  /// [sequence] was told as failing and [next] is the record that
  /// candidate's run read.
  ///
  /// [deleteSpan] goes on from [position], or where [next] proposes no
  /// candidate there, from the first candidate of the told candidate's span
  /// among [next]'s, so a list that lost its first element with the length
  /// before it lowered, the last place the pass deletes from, loses its next
  /// the same way. [moveValue] goes on from the first candidate of the told
  /// candidate's pair among [next]'s, so a value moved part way is moved
  /// again whole. Each goes on from the first of the spans or pairs after
  /// the told one where [next] is too short to hold it. Every other pass goes
  /// on from [position].
  int resumeAt(ChoiceSequence sequence, int position, ChoiceSequence next) =>
      switch (this) {
        deleteLast ||
        zeroBeneath ||
        liftSpan ||
        simplifySpan ||
        zeroSpan ||
        lowerChoice ||
        lowerTogether ||
        reorder ||
        swapSpan ||
        deleteAndLower ||
        lowerAndCopy ||
        deleteAndRaise => position,
        deleteSpan when _deleteSpans(next.choices).skip(position).isNotEmpty =>
          position,
        deleteSpan => _resumeInGroups(
          sequence,
          position,
          next,
          groups: _deletions,
          candidates: _deleteSpan,
          precedes: _deletedBefore,
        ),
        moveValue => _resumeInGroups(
          sequence,
          position,
          next,
          groups: _pairs,
          candidates: _moveValue,
          precedes: _precedes,
        ),
      };
}

/// The place among the candidates a pass proposes from [next] of the first
/// candidate of the group that holds the one at [position] among those it
/// proposes from [sequence], or of the first group after it where [next]
/// lacks that group.
///
/// The pass proposes, from a sequence of a length, the [candidates] of each
/// of the [groups] of that length in turn, and [precedes] tells whether one
/// group comes before another among them. Where no group holds [position],
/// it is every candidate the pass proposes from [next].
int _resumeInGroups<G>(
  ChoiceSequence sequence,
  int position,
  ChoiceSequence next, {
  required Iterable<G> Function(int length) groups,
  required Iterable<_Build> Function(List<Choice> choices, G group) candidates,
  required bool Function(G group, G other) precedes,
}) {
  G? told;
  for (final G group in groups(sequence.choices.length)) {
    position -= candidates(sequence.choices, group).length;
    if (position < 0) {
      told = group;
      break;
    }
  }
  int before = 0;
  for (final G group in groups(next.choices.length)) {
    if (told != null && !precedes(group, told)) break;
    before += candidates(next.choices, group).length;
  }
  return before;
}

/// A span [Pass.deleteSpan] deletes:
///
/// - `width`: how many choices it holds.
/// - `start`: the place of its first.
typedef _Deletion = ({int width, int start});

/// Each span [Pass.deleteSpan] deletes within [length] choices, the widest
/// first and each width from the end back.
Iterable<_Deletion> _deletions(int length) sync* {
  for (final int width in _widths) {
    for (final int start in _startsBack(length, width)) {
      yield (width: width, start: start);
    }
  }
}

/// Whether [deletion] comes before [other] among [_deletions].
bool _deletedBefore(_Deletion deletion, _Deletion other) =>
    deletion.width > other.width ||
    (deletion.width == other.width && deletion.start > other.start);

/// Two choices [Pass.moveValue] moves value between:
///
/// - `apart`: how many places after the first the second is.
/// - `first`: the place of the first.
typedef _Pair = ({int apart, int first});

/// Each pair of choices within [length], the farthest apart first and each
/// from the first on.
Iterable<_Pair> _pairs(int length) sync* {
  for (final int apart in _widths) {
    for (int first = 0; first + apart < length; first++) {
      yield (apart: apart, first: first);
    }
  }
}

/// Whether [pair] comes before [other] among [_pairs].
bool _precedes(_Pair pair, _Pair other) =>
    pair.apart > other.apart ||
    (pair.apart == other.apart && pair.first < other.first);

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

/// The candidates of [Pass.deleteSpan] from [choices].
Iterable<_Build> _deleteSpans(List<Choice> choices) =>
    _deletions(choices.length)
        .expand((_Deletion deletion) => _deleteSpan(choices, deletion));

/// The candidates of [Pass.deleteLast] from [choices].
Iterable<_Build> _deleteLast(List<Choice> choices) => _widths
    .where((int width) => width <= choices.length)
    .expand(
      (int width) =>
          _deleteSpan(choices, (width: width, start: choices.length - width)),
    );

/// The candidates of [Pass.deleteSpan] that delete [deletion]'s span of
/// [choices].
Iterable<_Build> _deleteSpan(List<Choice> choices, _Deletion deletion) sync* {
  final (:int width, :int start) = deletion;
  yield () => .new([...choices.take(start), ...choices.skip(start + width)]);
  if (start > 0 && choices[start - 1].value > 0) {
    yield () => .new([
      ...choices.take(start - 1),
      .new(choices[start - 1].value - 1),
      ...choices.skip(start + width),
    ]);
  }
}

Iterable<_Build> _zeroBeneath(List<Choice> choices, List<Span> spans) sync* {
  for (int i = 0; i < spans.length; i++) {
    final Span outer = spans[i];
    if (outer.depth > 0) continue;
    final List<Span> beneath = [
      for (int j = i + 1; j < spans.length && spans[j].depth > outer.depth; j++)
        spans[j],
    ];
    if (beneath.isEmpty) continue;
    yield () {
      final List<Choice> zeroed = [...choices];
      for (final Span inner in beneath) {
        zeroed.fillRange(inner.start, inner.start + inner.width, .new(0));
      }
      return .new(zeroed);
    };
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

Iterable<_Build> _simplifySpans(List<Choice> choices, List<Span> spans) sync* {
  for (final Span span in spans) {
    if (span.form case final ChoiceSequence form) {
      yield () => .new([
        ...choices.take(span.start),
        ...form.choices,
        ...choices.skip(span.start + span.width),
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

/// The candidates of [Pass.moveValue] that move value between [pair]'s
/// choices of [choices].
Iterable<_Build> _moveValue(List<Choice> choices, _Pair pair) sync* {
  final int i = pair.first;
  final int j = pair.first + pair.apart;
  final int from = choices[i].value;
  final int to = choices[j].value;
  for (final int lowered in _probes(from)) {
    final int moved = from - lowered;
    for (final int raised in [moved, if (moved > 1) moved - 1]) {
      if (raised > Choice.largest.value - to) continue;
      yield () => _replaced(choices, {i: .new(lowered), j: .new(to + raised)});
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

Iterable<_Build> _deleteAndRaise(List<Choice> choices) sync* {
  for (final int width in _widths) {
    for (final int start in _startsBack(choices.length - 1, width)) {
      final int after = start + width;
      final int? raised = _sum(choices.sublist(start, after + 1));
      if (raised == null || raised == choices[after].value) continue;
      yield () => .new([
        ...choices.take(start),
        .new(raised),
        ...choices.skip(after + 1),
      ]);
    }
  }
}

/// The sum of [choices], or null where it passes [Choice.largest].
int? _sum(List<Choice> choices) {
  int sum = 0;
  for (final Choice choice in choices) {
    if (choice.value > Choice.largest.value - sum) return null;
    sum += choice.value;
  }
  return sum;
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
