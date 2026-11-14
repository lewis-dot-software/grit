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

/// The longest sequence and the largest choice the exhaustive checks reach.
///
/// Every answer to every candidate is followed from each start, and the
/// paths grow past a million at a length of 3.
const int _length = 2;
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
      for (final bool failed in [true, false]) {
        steps.add((
          from: shrink.current,
          candidate: shrink.candidate,
          failed: failed,
        ));
        _everyPath(tell(shrink, failed: failed), onEnd, steps);
        steps.removeLast();
      }
  }
}

/// Fails the test where [holds] does not, naming [path], which is printed
/// only then since a path prints slowly.
void _hold(bool holds, List<ShrinkStep> path) {
  if (!holds) fail('$path');
}

/// Whether each candidate [path] told as failing became the current
/// sequence, in the next step or as [end]'s, and was shortlex smaller than
/// the one it replaced.
bool _acceptsOnlySmaller(List<ShrinkStep> path, Shrunk end) {
  for (int i = 0; i < path.length; i++) {
    final ShrinkStep step = path[i];
    if (!step.failed) continue;
    final ChoiceSequence next = i + 1 < path.length
        ? path[i + 1].from
        : end.current;
    if (next != step.candidate || !step.candidate.isSmallerThan(step.from)) {
      return false;
    }
  }
  return true;
}

/// Whether every current sequence along [path] from [first], and [end]'s,
/// is [first] or a candidate told as failing before it.
bool _holdsOnlyFailures(
  ChoiceSequence first,
  List<ShrinkStep> path,
  Shrunk end,
) {
  final Set<ChoiceSequence> toldFailing = {first};
  for (final ShrinkStep step in path) {
    if (!toldFailing.contains(step.from)) return false;
    if (step.failed) toldFailing.add(step.candidate);
  }
  return toldFailing.contains(end.current);
}

/// Whether shrinking [end]'s result again accepts a candidate, each told as
/// [told] answered it, and as failing where it was never asked of, so a
/// candidate the first shrinking never proposed is accepted where shrinking
/// again proposes it.
bool _acceptsAgain(Shrunk end, Map<ChoiceSequence, bool> told) {
  bool accepted = false;
  final ChoiceSequence again = end.current;
  shrunk(
    .start(again, spansOf(again)),
    treeFailing((ChoiceSequence candidate) {
      final bool failed = told[candidate] ?? true;
      accepted |= failed;
      return failed;
    }),
  );
  return accepted;
}

/// Every small sequence, each a first failure the exhaustive checks shrink.
Iterable<ChoiceSequence> get _firstFailures =>
    everySequence(length: _length, bound: _bound);

/// Whether [body] fails, run on the choices of [sequence] alone.
bool Function(ChoiceSequence) _failsOn(void Function(ChoiceSource) body) =>
    (ChoiceSequence sequence) {
      final ChoiceSource source = .fixed(sequence);
      return run(source, () => body(source)) == .failed;
    };

/// The smallest sequence shrinking [first] reaches, where a candidate fails
/// as [body] fails on it.
///
/// [body] draws through no generator, so its runs make no span.
ChoiceSequence _smallest(List<int> first, void Function(ChoiceSource) body) {
  final bool Function(ChoiceSequence) fails = _failsOn(body);
  expect(fails(sequenceOf(first)), isTrue, reason: '$first must fail');
  return shrunk(
    .start(sequenceOf(first), const []),
    (ChoiceSequence candidate) => fails(candidate) ? const [] : null,
  ).current;
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

    test('two equal choices shrink to both 0, which only zeroing a span '
        'reaches', () {
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
    final Shrink failed = tell(start, failed: true);
    expect((start.toldNotFailing() as Shrinking).candidate, passed.candidate);
    expect(tell(start, failed: true).current, failed.current);
    expect(start.candidate, candidate);
    expect(start.current, sequenceOf([2, 2]));
    expect(failed.current, candidate);
    expect(passed.current, sequenceOf([2, 2]));
  });

  group('over every small first failure and every answer', () {
    test('Shrinking always ends, whatever the oracle answers.', () {
      int ends = 0;
      for (final ChoiceSequence first in _firstFailures) {
        _everyPath(.start(first, spansOf(first)), (_, _) => ends++);
      }
      expect(ends, greaterThan(0));
    });

    test('Every accepted candidate is shortlex smaller than the sequence it '
        'replaces.', () {
      for (final ChoiceSequence first in _firstFailures) {
        _everyPath(
          .start(first, spansOf(first)),
          (List<ShrinkStep> path, Shrunk end) =>
              _hold(_acceptsOnlySmaller(path, end), path),
        );
      }
    });

    test('The current sequence is always the first failure or one the oracle '
        'said failed.', () {
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
          // A path that told one candidate both ways answers as no oracle
          // does. Any other is an oracle's.
          final Map<ChoiceSequence, bool> answers = {};
          for (final ShrinkStep step in path) {
            if (answers[step.candidate] case final bool told
                when told != step.failed) {
              return;
            }
            answers[step.candidate] = step.failed;
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

    property('Every accepted candidate is shortlex smaller than the sequence '
        'it replaces.', (Draw draw) {
      final ChoiceSequence first = draw(anySequence, label: 'first failure');
      final (List<ShrinkStep> path, Shrunk end) = answered(
        first,
        drawOracle(draw, first),
      );
      expect(_acceptsOnlySmaller(path, end), isTrue);
    });

    property('The current sequence is always the first failure or one the '
        'oracle said failed.', (Draw draw) {
      final ChoiceSequence first = draw(anySequence, label: 'first failure');
      final (List<ShrinkStep> path, Shrunk end) = answered(
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
      final Map<ChoiceSequence, bool> told = {};
      final Shrunk end = shrunk(
        .start(first, spansOf(first)),
        treeFailing(
          (ChoiceSequence candidate) => told.putIfAbsent(
            candidate,
            () => answerOf(oracle, told.length, candidate),
          ),
        ),
      );
      expect(_acceptsAgain(end, told), isFalse);
    });
  });
}
