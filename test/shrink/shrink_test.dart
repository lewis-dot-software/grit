import 'package:grit/grit.dart';
import 'package:grit/src/choice/bound.dart';
import 'package:grit/src/choice/choice_source.dart';
import 'package:grit/src/shrink/shrink.dart';
import 'package:test/test.dart';

import '../support/inputs.dart';
import '../support/oracle.dart';
import '../support/shrinking.dart';
import '../support/small.dart';
import '../support/spans.dart';

/// The longest sequence the exhaustive checks reach.
///
/// Every answer to every candidate is followed from each start, a failing
/// one for each count of its choices read, and the paths grow past a million
/// at a length of 3.
const int _length = 2;

/// The largest choice the exhaustive checks reach.
const int _bound = 2;

/// The most steps a path may take before it is held never to end, far past
/// the longest path the exhaustive checks follow.
const int _endless = 1000;

/// Calls [onEnd] with every path of answers from [shrink] to its end, and the
/// state it ends in, failing a path that passes [_endless] steps.
void _everyPath(
  Shrink shrink,
  void Function(List<ShrinkStep> path, Shrunk end) onEnd, [
  List<ShrinkStep>? path,
]) {
  final List<ShrinkStep> steps = path ?? [];
  switch (shrink) {
    case Shrunk():
      onEnd(steps, shrink);
    case Shrinking():
      if (steps.length >= _endless) {
        fail('${steps.first.from} passed $_endless steps');
      }
      final ChoiceSequence candidate = shrink.candidate;
      for (final int? read in [
        for (int read = 0; read <= candidate.choices.length; read++) read,
        null,
      ]) {
        steps.add((
          from: shrink.current,
          candidate: candidate,
          record: read == null ? null : recordOf(candidate, read),
        ));
        _everyPath(tell(shrink, read: read), onEnd, steps);
        steps.removeLast();
      }
  }
}

/// Fails the test where [holds] does not, naming [path], which is printed
/// only then since a path prints slowly.
void _hold(bool holds, List<ShrinkStep> path) {
  if (!holds) fail('$path');
}

/// Whether the record of each candidate [path] told as failing became the
/// current sequence, in the next step or as [end]'s, and was shortlex smaller
/// than the one it replaced.
bool _acceptsOnlySmaller(List<ShrinkStep> path, Shrunk end) {
  for (int i = 0; i < path.length; i++) {
    final ShrinkStep step = path[i];
    final ChoiceSequence? record = step.record;
    if (record == null) continue;
    final ChoiceSequence next = i + 1 < path.length
        ? path[i + 1].from
        : end.current;
    if (next != record || !record.isSmallerThan(step.from)) return false;
  }
  return true;
}

/// Whether every current sequence along [path] from [first], and [end]'s,
/// is [first] or the record of a candidate told as failing before it.
bool _holdsOnlyFailures(
  ChoiceSequence first,
  List<ShrinkStep> path,
  Shrunk end,
) {
  final Set<ChoiceSequence> toldFailing = {first};
  for (final ShrinkStep step in path) {
    if (!toldFailing.contains(step.from)) return false;
    if (step.record case final ChoiceSequence record) toldFailing.add(record);
  }
  return toldFailing.contains(end.current);
}

/// Whether shrinking [end]'s result again accepts a candidate, each told as
/// [told] answered it, a failing run having read as many of its choices as
/// [told] gives, and as failing having read every choice where it was never
/// asked of, so a candidate the first shrinking never proposed is accepted
/// where shrinking again proposes it.
bool _acceptsAgain(Shrunk end, Map<ChoiceSequence, int?> told) {
  bool accepted = false;
  final ChoiceSequence again = end.current;
  shrunk(.start(again, spansOf(again)), (ChoiceSequence candidate) {
    final int? read = told.containsKey(candidate)
        ? told[candidate]
        : candidate.choices.length;
    if (read == null) return null;
    accepted = true;
    return (read: read, spans: spansOf(recordOf(candidate, read)));
  });
  return accepted;
}

/// Every small sequence, each a first failure the exhaustive checks shrink.
Iterable<ChoiceSequence> get _firstFailures =>
    everySequence(length: _length, bound: _bound);

/// How many choices [body] read where it fails, run on the choices of
/// [sequence] alone, and null where it does not fail.
///
/// [body] draws through no generator, so its runs make no span.
Failing? Function(ChoiceSequence) _failsOn(void Function(ChoiceSource) body) =>
    (ChoiceSequence sequence) {
      final ChoiceSource source = .fixed(sequence);
      return run(source, () => body(source)) == .failed
          ? (read: source.length, spans: const [])
          : null;
    };

/// The smallest sequence shrinking [first] reaches, where a candidate fails
/// as [body] fails on it, the choices its run read becoming the current
/// sequence.
ChoiceSequence _smallest(List<int> first, void Function(ChoiceSource) body) {
  final Failing? Function(ChoiceSequence) fails = _failsOn(body);
  expect(fails(sequenceOf(first)), isNotNull, reason: '$first must fail');
  return shrunk(.start(sequenceOf(first), const []), fails).current;
}

/// Each element of a list drawn behind a "one more" choice, each from 0 to
/// [bound].
List<int> _drawList(ChoiceSource source, int bound) {
  final List<int> list = [];
  while (source.weigh(.new(0.5))) {
    list.add(source.choose(.new(bound)).value);
  }
  return list;
}

void main() {
  group('known smallest cases', () {
    test('a list holding an element of 5 or more shrinks to that element '
        'alone, at 5', () {
      expect(
        _smallest([1, 7, 1, 9, 1, 2, 0], (ChoiceSource source) {
          if (_drawList(source, 9).any((int x) => x >= 5)) throw 'large';
        }),
        sequenceOf([1, 5, 0]),
      );
    });

    test('a body that fails on its first choice shrinks to that choice '
        'alone, at 0', () {
      expect(
        _smallest([4, 4, 4], (ChoiceSource source) {
          source.choose(.new(9));
          throw 'any';
        }),
        sequenceOf([0]),
      );
    });

    test('two choices summing to 10 or more, each up to 9, shrink to 1 and '
        '9', () {
      expect(
        _smallest([9, 9], (ChoiceSource source) {
          final int a = source.choose(.new(9)).value;
          final int b = source.choose(.new(9)).value;
          if (a + b >= 10) throw 'sum';
        }),
        sequenceOf([1, 9]),
      );
    });

    test('two equal choices shrink to both 0', () {
      expect(
        _smallest([5, 5], (ChoiceSource source) {
          if (source.choose(.new(9)) == source.choose(.new(9))) throw 'equal';
        }),
        sequenceOf([0, 0]),
      );
    });

    test('two choices of 1 and 3 in either order shrink to 1 then 3', () {
      expect(
        _smallest([3, 1], (ChoiceSource source) {
          final Set<int> drawn = {
            source.choose(.new(9)).value,
            source.choose(.new(9)).value,
          };
          if (drawn.containsAll([1, 3]) && drawn.length == 2) throw 'pair';
        }),
        sequenceOf([1, 3]),
      );
    });

    test('a 1 and a 3 either side of a 5 shrink to 1, 5, 3 by a swap', () {
      expect(
        _smallest([3, 5, 1], (ChoiceSource source) {
          final int a = source.choose(.new(9)).value;
          final int b = source.choose(.new(9)).value;
          final int c = source.choose(.new(9)).value;
          if (b == 5 && {a, c}.containsAll([1, 3]) && a != c) throw 'swap';
        }),
        sequenceOf([1, 5, 3]),
      );
    });

    test('two choices summing to exactly 10 shrink to 0 and 10 by moving '
        'value', () {
      expect(
        _smallest([7, 3], (ChoiceSource source) {
          final Bound bound = .new(10);
          if (source.choose(bound).value + source.choose(bound).value == 10) {
            throw 'ten';
          }
        }),
        sequenceOf([0, 10]),
      );
    });

    test('a choice failing on even values alone, as a negative integer does '
        'by its zigzag, shrinks to the smallest even value but 0', () {
      expect(
        _smallest([1022], (ChoiceSource source) {
          final int x = source.choose(.new(1 << 20)).value;
          if (x > 0 && x.isEven) throw 'negative';
        }),
        sequenceOf([2]),
      );
    });

    test('a list whose length is read before its elements shrinks to its one '
        'failing element, by deleting each other with the length lowered', () {
      // Every element is at least 1 to fail, so no deletion that leaves an
      // element of 0 standing as the length fails.
      expect(
        _smallest([3, 1, 1, 1, 7], (ChoiceSource source) {
          final int length = source.choose(.new(9)).value;
          final List<int> elements = [
            for (int i = 0; i <= length; i++) source.choose(.new(9)).value,
          ];
          if (elements.every((int x) => x >= 1) &&
              elements.any((int x) => x >= 7)) {
            throw 'large';
          }
        }),
        sequenceOf([0, 7]),
      );
    });

    test('two equal choices of 10 or more shrink to both 10 by lowering them '
        'together', () {
      expect(
        _smallest([500, 500], (ChoiceSource source) {
          final int a = source.choose(.new(1000)).value;
          final int b = source.choose(.new(1000)).value;
          if (a >= 10 && a == b) throw 'equal';
        }),
        sequenceOf([10, 10]),
      );
    });

    test('a list holding two elements that index each other, behind four '
        'elements of 0, shrinks to the two alone, by deleting an element with '
        'both lowered', () {
      // No list of six elements smaller than [0, 0, 0, 0, 5, 4] fails, and
      // deleting an element alone leaves an index past the list's end.
      expect(
        _smallest([1, 0, 1, 0, 1, 0, 1, 0, 1, 5, 1, 4, 0], (
          ChoiceSource source,
        ) {
          final List<int> list = _drawList(source, 10);
          if (list.any((int x) => x >= list.length)) return;
          for (int i = 0; i < list.length; i++) {
            final int j = list[i];
            if (j != i && list[j] == i) throw 'coupled';
          }
        }),
        sequenceOf([1, 1, 1, 0, 0]),
      );
    });

    test('a value needing a later option while the earlier one is empty '
        'shrinks to 0 with the earlier option taken, by lowering it and '
        'copying the later choice into the 0', () {
      // An option is taken where its first choice is 3, then holds a value.
      int? option(ChoiceSource source) => source.choose(.new(3)).value == 3
          ? source.choose(.new(9)).value
          : null;
      expect(
        _smallest([1, 0, 3, 0], (ChoiceSource source) {
          final int value = source.choose(.new(9)).value;
          final int? earlier = option(source);
          final int? later = option(source);
          if (value == 0 ? earlier != null : later != null) throw 'option';
        }),
        sequenceOf([0, 3, 0, 0]),
      );
    });

    test('a first failure no candidate of which fails is its own smallest', () {
      final ChoiceSequence first = sequenceOf([3, 1, 2]);
      final Shrunk end = shrunk(.start(first, spansOf(first)), (_) => null);
      expect(end.current, sequenceOf([3, 1, 2]));
    });

    test('the empty first failure ends at once, proposing nothing', () {
      final Shrink start = .start(sequenceOf([]), const []);
      expect(start, isA<Shrunk>());
      expect(start.current, sequenceOf([]));
    });
  });

  test('a state is unchanged by a step taken from it, so each answer to it '
      'leads to the same next state', () {
    final ChoiceSequence first = sequenceOf([2, 2]);
    final Shrinking start = Shrink.start(first, spansOf(first)) as Shrinking;
    final ChoiceSequence candidate = start.candidate;
    final Shrinking passed = start.toldNotFailing() as Shrinking;
    final int read = candidate.choices.length;
    final Shrink failed = tell(start, read: read);
    expect((start.toldNotFailing() as Shrinking).candidate, passed.candidate);
    expect(tell(start, read: read).current, failed.current);
    expect(start.candidate, candidate);
    expect(start.current, sequenceOf([2, 2]));
    expect(failed.current, candidate);
    expect(passed.current, sequenceOf([2, 2]));
  });

  test('a candidate told as failing having read a prefix of its choices '
      'leaves that prefix the current sequence, and proposes next only '
      'candidates smaller than it', () {
    final ChoiceSequence first = sequenceOf(List.filled(10, 1));
    final Shrinking start = Shrink.start(first, spansOf(first)) as Shrinking;
    final ChoiceSequence candidate = start.candidate;
    expect(candidate.choices.length, greaterThan(1));
    final Shrinking told = tell(start, read: 1) as Shrinking;
    expect(told.current, recordOf(candidate, 1));
    expect(told.candidate.isSmallerThan(told.current), isTrue);
  });

  test('a candidate told as failing having read none of its choices, or '
      'more than it holds, throws a RangeError for none but the first', () {
    final ChoiceSequence first = sequenceOf(List.filled(10, 1));
    final Shrinking start = Shrink.start(first, spansOf(first)) as Shrinking;
    final int length = start.candidate.choices.length;
    expect(start.toldFailing(read: 0, spans: const []).current, sequenceOf([]));
    for (final int read in [-1, length + 1]) {
      expect(
        () => start.toldFailing(read: read, spans: const []),
        throwsRangeError,
        reason: '$read',
      );
    }
  });

  test('a candidate moving value part way, told as failing, is followed by '
      'its pair moved whole', () {
    // Only moving value proposes [4, 2] from [6, 0], from the middle of the
    // pair's candidates.
    final ChoiceSequence first = sequenceOf([6, 0]);
    final ChoiceSequence partWay = sequenceOf([4, 2]);
    final List<ChoiceSequence> proposed = [];
    shrunk(.start(first, spansOf(first)), (ChoiceSequence candidate) {
      proposed.add(candidate);
      return candidate == partWay
          ? (read: candidate.choices.length, spans: spansOf(candidate))
          : null;
    });
    expect(proposed[proposed.indexOf(partWay) + 1], sequenceOf([0, 6]));
  });

  test('a candidate deleting the first element of a list and lowering its '
      'length, told as failing, is followed by the same deletion from the '
      'shorter list', () {
    // A length, then as many elements as it counts, fails in any form.
    final ChoiceSequence first = sequenceOf([3, 5, 5, 5]);
    final ChoiceSequence shorter = sequenceOf([2, 5, 5]);
    final List<ChoiceSequence> proposed = [];
    shrunk(.start(first, spansOf(first)), (ChoiceSequence candidate) {
      proposed.add(candidate);
      final List<Choice> choices = candidate.choices;
      return choices.isNotEmpty && choices.first.value == choices.length - 1
          ? (read: choices.length, spans: spansOf(candidate))
          : null;
    });
    final int after = proposed.indexOf(shorter) + 1;
    expect(proposed.sublist(after, after + 2), [
      sequenceOf([2, 5]),
      sequenceOf([1, 5]),
    ]);
  });

  test('a round that has accepted a candidate takes no costly pass, so its '
      'candidates wait for a round that accepts nothing', () {
    // Only lowering and copying proposes [0, 3, 3], and only deleting and
    // raising [5], from [2, 0, 3], told as failing in the first round. The
    // empty sequence opens each round of [2, 0, 3].
    final ChoiceSequence first = sequenceOf([2, 0, 3, 3]);
    final ChoiceSequence accepted = sequenceOf([2, 0, 3]);
    final List<ChoiceSequence> proposed = [];
    shrunk(.start(first, spansOf(first)), (ChoiceSequence candidate) {
      proposed.add(candidate);
      return candidate == accepted
          ? (read: candidate.choices.length, spans: spansOf(candidate))
          : null;
    });
    final int lastRound = proposed.lastIndexOf(sequenceOf([]));
    for (final List<int> costly in [
      [0, 3, 3],
      [5],
    ]) {
      final int at = proposed.indexOf(sequenceOf(costly));
      expect(at, isNot(-1), reason: '$costly is proposed');
      expect(at, greaterThan(lastRound), reason: '$costly waits');
    }
  });

  group('over every small first failure and every answer', () {
    test('Shrinking always ends, whatever the oracle answers.', () {
      int ends = 0;
      for (final ChoiceSequence first in _firstFailures) {
        _everyPath(.start(first, spansOf(first)), (_, _) => ends++);
      }
      expect(ends, greaterThan(0));
    });

    test('Every accepted candidate\'s record is shortlex smaller than the '
        'sequence it replaces.', () {
      for (final ChoiceSequence first in _firstFailures) {
        _everyPath(
          .start(first, spansOf(first)),
          (List<ShrinkStep> path, Shrunk end) =>
              _hold(_acceptsOnlySmaller(path, end), path),
        );
      }
    });

    test('The current sequence is always the record the first failure\'s run '
        'read, or one a candidate\'s run read when told it failed.', () {
      for (final ChoiceSequence first in _firstFailures) {
        _everyPath(
          .start(first, spansOf(first)),
          (List<ShrinkStep> path, Shrunk end) =>
              _hold(_holdsOnlyFailures(first, path, end), path),
        );
      }
    });

    test('Shrinking the result again accepts nothing, so the result is a fixed '
        'point.', () {
      int oracles = 0;
      for (final ChoiceSequence first in _firstFailures) {
        _everyPath(.start(first, spansOf(first)), (
          List<ShrinkStep> path,
          Shrunk end,
        ) {
          // A path that told one candidate two ways answers as no oracle
          // does. Any other is an oracle's.
          final Map<ChoiceSequence, int?> answers = {};
          for (final ShrinkStep step in path) {
            final int? read = step.record?.choices.length;
            if (answers.containsKey(step.candidate) &&
                answers[step.candidate] != read) {
              return;
            }
            answers[step.candidate] = read;
          }
          oracles++;
          _hold(!_acceptsAgain(end, answers), path);
        });
      }
      expect(oracles, greaterThan(0));
    });
  });

  group('on grit, over larger first failures and answers', () {
    property('Shrinking always ends, whatever the oracle answers.', (
      Draw draw,
    ) {
      final ChoiceSequence first = draw(anySequence, label: 'first failure');
      answered(first, drawOracle(draw, first));
    });

    property('Every accepted candidate\'s record is shortlex smaller than the '
        'sequence it replaces.', (Draw draw) {
      final ChoiceSequence first = draw(anySequence, label: 'first failure');
      final (:List<ShrinkStep> path, :Shrunk end) = answered(
        first,
        drawOracle(draw, first),
      );
      expect(_acceptsOnlySmaller(path, end), isTrue);
    });

    property('The current sequence is always the record the first failure\'s '
        'run read, or one a candidate\'s run read when told it failed.', (
      Draw draw,
    ) {
      final ChoiceSequence first = draw(anySequence, label: 'first failure');
      final (:List<ShrinkStep> path, :Shrunk end) = answered(
        first,
        drawOracle(draw, first),
      );
      expect(_holdsOnlyFailures(first, path, end), isTrue);
    });

    property('Shrinking the result again accepts nothing, so the result is a '
        'fixed point.', (Draw draw) {
      final ChoiceSequence first = draw(anySequence, label: 'first failure');
      final Oracle oracle = drawOracle(draw, first);
      // An oracle answers alike each time it is asked of one candidate, each
      // candidate first asked taking its next answer.
      final Map<ChoiceSequence, int?> told = {};
      final Shrunk end = shrunk(.start(first, spansOf(first)), (
        ChoiceSequence candidate,
      ) {
        final int? read = told.putIfAbsent(
          candidate,
          () => answerOf(oracle, told.length, candidate),
        );
        if (read == null) return null;
        return (read: read, spans: spansOf(recordOf(candidate, read)));
      });
      expect(_acceptsAgain(end, told), isFalse);
    });
  });
}
