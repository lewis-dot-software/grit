import 'dart:math';

import 'package:grit/grit.dart';
import 'package:grit/src/choice/bound.dart';
import 'package:grit/src/choice/choice_source.dart';
import 'package:grit/src/choice/odds.dart';
import 'package:grit/src/choice/status.dart';
import 'package:test/test.dart';

import '../support/fixed_random.dart';
import '../support/inputs.dart';
import '../support/small.dart';

/// The largest choice and length the exhaustive checks reach.
const int _bound = 3;
const int _length = 4;

/// The bound every choice lies within.
final Bound _widest = .new(Choice.largest.value);

/// Odds from 0 to 1 in hundredths.
final Gen<Odds> _odds = .integer(
  min: 0,
  max: 100,
).map((int hundredths) => .new(hundredths / 100));

/// One ask a run makes of its source.
sealed class _Ask {
  _Ask._();
}

/// An ask for a choice up to [bound].
final class _Choose extends _Ask {
  _Choose(this.bound) : super._();

  final Bound bound;

  @override
  String toString() => 'choose up to $bound';
}

/// An ask for a weighted choice at [odds].
final class _Weigh extends _Ask {
  _Weigh(this.odds) : super._();

  final Odds odds;

  @override
  String toString() => 'weigh at $odds';
}

/// An ask for a choice up to a bound at any scale, or for a weighted choice
/// at any odds.
final Gen<_Ask> _ask = .build(
  (Draw draw) => draw(.boolean())
      ? _Weigh(draw(_odds))
      : _Choose(.new(draw(anyChoice).value)),
);

void main() {
  group('a fixed source', () {
    test('hands a run exactly its sequence\'s choices in order, and a run '
        'that asks past its end ends overrun', () {
      for (final ChoiceSequence sequence in everySequence(
        length: _length,
        bound: _bound,
      )) {
        final int size = sequence.choices.length;
        for (int asks = 0; asks <= size + 2; asks++) {
          final ChoiceSource source = .fixed(sequence);
          final List<Choice> handed = [];
          final Status status = run(source, () {
            for (int i = 0; i < asks; i++) {
              handed.add(source.choose(.new(_bound)));
            }
          });
          final String reason = '$sequence asked $asks times';
          expect(
            handed,
            sequence.choices.take(min(asks, size)),
            reason: reason,
          );
          expect(source.record.choices, handed, reason: reason);
          expect(
            status,
            asks > size ? Status.overrun : Status.returned,
            reason: reason,
          );
        }
      }
    });

    test('a fixed choice above the bound a generator now asks for ends the run '
        'rejected', () {
      for (int size = 0; size <= _length; size++) {
        final List<ChoiceSequence> sequences = everySequenceOf(
          size: size,
          bound: _bound,
        ).toList();
        for (final ChoiceSequence sequence in sequences) {
          for (final ChoiceSequence bounds in sequences) {
            final ChoiceSource source = .fixed(sequence);
            final Status status = run(source, () {
              for (final Choice bound in bounds.choices) {
                source.choose(.new(bound.value));
              }
            });
            final int firstAbove = [for (int i = 0; i < size; i++) i]
                .firstWhere(
                  (int i) =>
                      sequence.choices[i].value > bounds.choices[i].value,
                  orElse: () => -1,
                );
            final String reason = '$sequence under $bounds';
            if (firstAbove == -1) {
              expect(status, Status.returned, reason: reason);
              expect(source.record, sequence, reason: reason);
            } else {
              expect(status, Status.rejected, reason: reason);
              expect(
                source.record.choices,
                sequence.choices.take(firstAbove),
                reason: reason,
              );
            }
          }
        }
      }
    });

    test('reads a weighted choice of 0 as false and 1 as true', () {
      final ChoiceSource source = .fixed(sequenceOf([1, 0]));
      expect(source.weigh(.new(0.01)), isTrue);
      expect(source.weigh(.new(0.99)), isFalse);
      expect(source.record, sequenceOf([1, 0]));
    });

    test('rejects a weighted choice above 1', () {
      final ChoiceSource source = .fixed(sequenceOf([2]));
      expect(run(source, () => source.weigh(.new(0.5))), Status.rejected);
    });

    test('ends overrun at a weighted choice past its end', () {
      final ChoiceSource source = .fixed(.empty);
      expect(run(source, () => source.weigh(.new(0.5))), Status.overrun);
    });
  });

  group('a random fill', () {
    test('never gives a choice above the bound asked for, nor more choices '
        'than its limit', () {
      // Each ask is a choice up to the bound its value names, or a weighted
      // choice where its value is one past the largest bound.
      for (int seed = 0; seed < 3; seed++) {
        for (int limit = 0; limit <= _length; limit++) {
          for (final ChoiceSequence asks in everySequence(
            length: _length + 1,
            bound: _bound + 1,
          )) {
            final ChoiceSource source = .random(.new(seed), limit: limit);
            final List<(Bound, Choice)> handed = [];
            final Status status = run(source, () {
              for (final Choice ask in asks.choices) {
                if (ask.value > _bound) {
                  final bool weighed = source.weigh(.new(0.5));
                  handed.add((.binary, .new(weighed ? 1 : 0)));
                } else {
                  final Bound bound = .new(ask.value);
                  handed.add((bound, source.choose(bound)));
                }
              }
            });
            final String reason = 'seed $seed, limit $limit, asks $asks';
            for (final (Bound bound, Choice choice) in handed) {
              expect(bound.admits(choice), isTrue, reason: reason);
            }
            expect(source.record.choices, hasLength(handed.length));
            expect(handed.length, lessThanOrEqualTo(limit), reason: reason);
            expect(
              status,
              asks.choices.length > limit ? Status.overrun : Status.returned,
              reason: reason,
            );
          }
        }
      }
    });

    test('fills bounds past one word within the bound', () {
      for (final int value in [
        (1 << 32) - 1,
        1 << 32,
        (1 << 32) + 1,
        1 << 62,
      ]) {
        final Bound bound = .new(value);
        final ChoiceSource source = .random(.new(value), limit: 200);
        for (int i = 0; i < 200; i++) {
          expect(bound.admits(source.choose(bound)), isTrue, reason: '$value');
        }
      }
    });

    test('fills the widest bound across its whole width', () {
      final Bound widest = .new(0x7FFFFFFFFFFFFFFF);
      final ChoiceSource source = .random(.new(1), limit: 200);
      final List<Choice> choices = [
        for (int i = 0; i < 200; i++) source.choose(widest),
      ];
      expect(choices.any((Choice c) => c.value >= 1 << 62), isTrue);
    });

    test('fills a bound of one word with every choice within it', () {
      final ChoiceSource source = .random(.new(0), limit: 200);
      final Set<Choice> filled = {
        for (int i = 0; i < 200; i++) source.choose(.new(3)),
      };
      expect(filled, <Choice>{.new(0), .new(1), .new(2), .new(3)});
    });

    test('fills a bound of 0 with 0', () {
      final ChoiceSource source = .random(.new(0), limit: 5);
      for (int i = 0; i < 5; i++) {
        expect(source.choose(.new(0)), Choice(0));
      }
    });

    test('fills alike from the same seed', () {
      ChoiceSequence fill(int seed) {
        final ChoiceSource source = .random(.new(seed), limit: 20);
        for (int i = 0; i < 20; i++) {
          source.choose(.new(1000));
        }
        return source.record;
      }

      expect(fill(7), fill(7));
    });

    test('weighs at odds of 0 as false and 1 as true', () {
      final ChoiceSource source = .random(.new(0), limit: 100);
      for (int i = 0; i < 50; i++) {
        expect(source.weigh(.new(0)), isFalse);
        expect(source.weigh(.new(1)), isTrue);
      }
    });

    test('weighs true below the odds asked and false from them up', () {
      for (final double odds in [0.25, 0.5, 0.75]) {
        for (final (double draw, bool weighed) in [
          (0, true),
          (odds - 0.01, true),
          (odds, false),
          (odds + 0.01, false),
        ]) {
          final ChoiceSource source = .random(FixedRandom(draw), limit: 1);
          expect(
            source.weigh(.new(odds)),
            weighed,
            reason: 'draw $draw at $odds',
          );
          expect(source.record, sequenceOf([if (weighed) 1 else 0]));
        }
      }
    });

    test('at edges of 1 fills every choice at 0 or at its bound, each in '
        'turn', () {
      for (final int bound in [0, 1, 3, 1000, 1 << 40]) {
        final ChoiceSource source = .random(
          .new(bound),
          limit: 200,
          edges: .new(1),
        );
        final Set<Choice> filled = {
          for (int i = 0; i < 200; i++) source.choose(.new(bound)),
        };
        expect(filled, <Choice>{.new(0), .new(bound)}, reason: '$bound');
      }
    });

    test('at edges of 1/2 fills about half its choices at 0 or at its bound, '
        'and the rest within it', () {
      final Bound bound = .new(1000);
      final ChoiceSource source = .random(
        .new(3),
        limit: 1000,
        edges: .new(0.5),
      );
      final List<Choice> filled = [
        for (int i = 0; i < 1000; i++) source.choose(bound),
      ];
      final int edges = filled
          .where((Choice c) => c.value == 0 || c.value == bound.value)
          .length;
      expect(edges, inInclusiveRange(400, 600));
      expect(filled.every(bound.admits), isTrue);
    });

    test('weighs at its own odds whatever its edges', () {
      final ChoiceSource source = .random(.new(0), limit: 100, edges: .new(1));
      for (int i = 0; i < 50; i++) {
        expect(source.weigh(.new(0)), isFalse);
        expect(source.weigh(.new(1)), isTrue);
      }
    });

    test('counts a weighted choice against its limit', () {
      final ChoiceSource source = .random(.new(0), limit: 1);
      expect(
        run(source, () {
          source.weigh(.new(0.5));
          source.choose(.new(1));
        }),
        Status.overrun,
      );
      expect(source.record.choices, hasLength(1));
    });
  });

  group('a run\'s status', () {
    test('is returned where the body returned', () {
      final ChoiceSource source = .fixed(sequenceOf([0]));
      expect(run(source, () => source.choose(.new(1))), Status.returned);
    });

    test('is failed where the body threw', () {
      final ChoiceSource source = .fixed(sequenceOf([0]));
      expect(
        run(source, () {
          source.choose(.new(1));
          throw StateError('the property failed');
        }),
        Status.failed,
      );
    });

    test('is rejected where the body rejected it', () {
      final ChoiceSource source = .fixed(.empty);
      expect(run(source, source.reject), Status.rejected);
    });

    test('stays the source\'s stop where the body caught it and returned', () {
      final ChoiceSource source = .fixed(.empty);
      final Status status = run(source, () {
        try {
          source.choose(.new(1));
        } on Object {
          // The body swallows the stop.
        }
      });
      expect(status, Status.overrun);
    });

    test('stays the source\'s stop where the body caught it and threw', () {
      final ChoiceSource source = .fixed(sequenceOf([2]));
      final Status status = run(source, () {
        try {
          source.choose(.new(1));
        } on Object {
          throw StateError('another failure');
        }
      });
      expect(status, Status.rejected);
    });

    // Each stop beside a source whose later asks would be handed over, or
    // stop otherwise, were the source to forget it had stopped.
    final List<
      (String, Status, ChoiceSource Function(), void Function(ChoiceSource))
    >
    stops = [
      (
        'an overrun',
        .overrun,
        () => .fixed(.empty),
        (ChoiceSource source) => source.choose(.new(1)),
      ),
      (
        'a fixed choice above its bound',
        .rejected,
        () => .fixed(sequenceOf([1, 0])),
        (ChoiceSource source) => source.choose(.new(0)),
      ),
      (
        'a weighted choice above 1',
        .rejected,
        () => .fixed(sequenceOf([2, 0])),
        (ChoiceSource source) => source.weigh(.new(0.5)),
      ),
      (
        'a reject',
        .rejected,
        () => .fixed(sequenceOf([0, 1])),
        (ChoiceSource source) => source.reject(),
      ),
    ];
    final List<(String, void Function(ChoiceSource))> asks = [
      ('a choice', (ChoiceSource source) => source.choose(.new(3))),
      ('a weighted choice', (ChoiceSource source) => source.weigh(.new(0.5))),
      ('a reject', (ChoiceSource source) => source.reject()),
    ];
    for (final (
          String stop,
          Status stopped,
          ChoiceSource Function() make,
          void Function(ChoiceSource) first,
        )
        in stops) {
      for (final (String ask, void Function(ChoiceSource) then) in asks) {
        test('keeps the stop of $stop, and stops $ask asked after it', () {
          final ChoiceSource source = make();
          expect(() => first(source), throwsException);
          expect(() => then(source), throwsException);
          expect(() => then(source), throwsException);
          expect(source.status(threw: false), stopped);
          expect(source.status(threw: true), stopped);
          expect(source.record, ChoiceSequence.empty);
        });
      }
    }
  });

  group('a bug in grit', () {
    test('a negative bound is thrown', () {
      expect(() => Bound(-1), throwsRangeError);
    });

    test('a negative limit is thrown', () {
      expect(() => ChoiceSource.random(.new(0), limit: -1), throwsRangeError);
    });

    test('odds outside 0 to 1 are thrown', () {
      for (final double odds in [-0.1, 1.1, .nan]) {
        expect(() => Odds(odds), throwsRangeError, reason: '$odds');
      }
    });
  });

  group('on grit, over larger inputs', () {
    property('A fixed source hands a run exactly its sequence\'s choices in '
        'order, and a run that asks past its end ends overrun.', (Draw draw) {
      final ChoiceSequence sequence = draw(anySequence, label: 'sequence');
      final int size = sequence.choices.length;
      final int asks = draw(.integer(min: 0, max: size + 4), label: 'asks');
      final ChoiceSource source = .fixed(sequence);
      final List<Choice> handed = [];
      final Status status = run(source, () {
        for (int i = 0; i < asks; i++) {
          handed.add(source.choose(_widest));
        }
      });
      expect(handed, sequence.choices.take(min(asks, size)));
      expect(source.record.choices, handed);
      expect(status, asks > size ? Status.overrun : Status.returned);
    });

    property('A random fill never gives a choice above the bound asked for, '
        'nor more choices than its limit.', (Draw draw) {
      final int seed = draw(.integer(min: 0, max: 0xFFFFFFFF), label: 'seed');
      final int limit = draw(.integer(min: 0, max: 64), label: 'limit');
      final ChoiceSource source = .random(
        .new(seed),
        limit: limit,
        edges: draw(_odds, label: 'edges'),
      );
      final List<_Ask> asks = draw(.list(_ask), label: 'asks');
      final List<(Bound, Choice)> handed = [];
      final Status status = run(source, () {
        for (final _Ask ask in asks) {
          handed.add(switch (ask) {
            _Choose(:final Bound bound) => (bound, source.choose(bound)),
            _Weigh(:final Odds odds) => (
              .binary,
              .new(source.weigh(odds) ? 1 : 0),
            ),
          });
        }
      });
      for (final (Bound bound, Choice choice) in handed) {
        expect(bound.admits(choice), isTrue, reason: '$choice above $bound');
      }
      expect(source.record.choices, hasLength(handed.length));
      expect(handed.length, lessThanOrEqualTo(limit));
      expect(status, asks.length > limit ? Status.overrun : Status.returned);
    });

    property('A fixed choice above the bound a generator now asks for ends '
        'the run rejected.', (Draw draw) {
      // Each choice is asked for under the bound drawn beside it, each at a
      // scale of its own, so a choice lies above its bound as often as not.
      final List<(Choice, Choice)> pairs = draw(
        .list(.build((Draw draw) => (draw(anyChoice), draw(anyChoice)))),
        label: 'choices and bounds',
      );
      final ChoiceSequence sequence = .new([
        for (final (Choice choice, _) in pairs) choice,
      ]);
      final ChoiceSource source = .fixed(sequence);
      final Status status = run(source, () {
        for (final (_, Choice bound) in pairs) {
          source.choose(.new(bound.value));
        }
      });
      final int firstAbove = pairs.indexWhere(
        ((Choice, Choice) pair) => pair.$1.value > pair.$2.value,
      );
      if (firstAbove == -1) {
        expect(status, Status.returned);
        expect(source.record, sequence);
      } else {
        expect(status, Status.rejected);
        expect(source.record.choices, sequence.choices.take(firstAbove));
      }
    });
  });
}
