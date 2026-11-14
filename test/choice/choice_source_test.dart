import 'dart:math';

import 'package:grit/grit.dart';
import 'package:grit/src/choice/bound.dart';
import 'package:grit/src/choice/choice_source.dart';
import 'package:grit/src/choice/odds.dart';
import 'package:grit/src/choice/status.dart';
import 'package:grit/src/choice/sweep.dart';
import 'package:grit/src/choice/zigzag.dart';
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

/// An ask for a choice up to [bound], naming [edges].
final class _Choose extends _Ask {
  _Choose(this.bound, {this.edges = const []}) : super._();

  final Bound bound;
  final List<Choice> edges;

  @override
  String toString() =>
      'choose up to $bound${edges.isEmpty ? '' : ' naming $edges'}';
}

/// An ask for a weighted choice at [odds].
final class _Weigh extends _Ask {
  _Weigh(this.odds) : super._();

  final Odds odds;

  @override
  String toString() => 'weigh at $odds';
}

/// An ask for a choice up to a bound at any scale, naming a few edges
/// within it, or for a weighted choice at any odds.
final Gen<_Ask> _ask = .build((Draw draw) {
  if (draw(.boolean())) return _Weigh(draw(_odds));
  final Bound bound = .new(draw(anyChoice).value);
  return _Choose(bound, edges: draw(_edgesWithin(bound)));
});

/// A few edges within [bound], its ends and its middle among them.
Gen<List<Choice>> _edgesWithin(Bound bound) => .list(
  .oneOf([
    .element([0, bound.value, bound.value ~/ 2]),
    .integer(min: 0, max: bound.value),
  ]).map(Choice.new),
  maxLength: 3,
);

/// The bounds the exhaustive checks of a random fill ask under, by the
/// choice that names each: a bound of 0, a bit, a few values and the
/// largest a choice holds, where a step past it would wrap.
final List<Bound> _scaled = [
  .new(0),
  .binary,
  .new(_bound),
  .new(Choice.largest.value),
];

/// The odds the exhaustive checks fill at: never, even and always.
final List<Odds> _someOdds = [.never, .new(0.5), .new(1)];

/// The choices a random fill hands [asks], each a choice under the bound
/// [_scaled] names where its value names one, naming the edges 0 and the
/// bound's middle, and a weighted choice where it is one past, each with the
/// bound it lies within.
List<(Bound, Choice)> _handedTo(ChoiceSource source, ChoiceSequence asks) {
  final List<(Bound, Choice)> handed = [];
  run(source, () {
    for (final Choice ask in asks.choices) {
      if (ask.value == _scaled.length) {
        handed.add((.binary, .new(source.weigh(.new(0.5)) ? 1 : 0)));
      } else {
        final Bound bound = _scaled[ask.value];
        handed.add((
          bound,
          source.choose(bound, edges: [.new(0), .new(bound.value ~/ 2)]),
        ));
      }
    }
  });
  return handed;
}

void main() {
  group('a fixed source', () {
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
      final ChoiceSource source = .fixed(sequenceOf([]));
      expect(run(source, () => source.weigh(.new(0.5))), Status.overrun);
    });
  });

  group('a random fill', () {
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
      final ChoiceSource source = .random(.new(1), limit: 200);
      final List<Choice> choices = [
        for (int i = 0; i < 200; i++) source.choose(_widest),
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

    test('at edges of 1 fills a choice that names edges at 0, at its bound or '
        'at each edge it names, each in turn', () {
      final Bound bound = .new(1000);
      final List<Choice> edges = [.new(1), .new(500), .new(999)];
      final ChoiceSource source = .random(.new(5), limit: 400, edges: .new(1));
      final List<Choice> filled = [
        for (int i = 0; i < 400; i++) source.choose(bound, edges: edges),
      ];
      expect(filled.toSet(), <Choice>{.new(0), .new(bound.value), ...edges});
      // Each of the five is filled about a fifth of the time, its spread
      // about 8, so a count past 30 off it is no fill alike.
      for (final Choice edge in [.new(0), .new(bound.value), ...edges]) {
        expect(
          filled.where((Choice c) => c == edge).length,
          inInclusiveRange(50, 110),
          reason: '$edge in $filled',
        );
      }
    });

    test('at near of 1 fills a choice under an earlier one\'s bound at it or '
        'one either side of it, each in turn, within the bound', () {
      // Each first choice is filled at an edge, 0 or the bound, so the
      // second is filled beside an end, where a step past it stays put.
      for (final Bound bound in [.new(1000), .new(Choice.largest.value)]) {
        final Map<Choice, Set<Choice>> besides = {};
        for (int seed = 0; seed < 200; seed++) {
          final ChoiceSource source = .random(
            .new(seed),
            limit: 2,
            near: .new(1),
            edges: .new(1),
          );
          final Choice first = source.choose(bound);
          (besides[first] ??= {}).add(source.choose(bound));
        }
        expect(besides, {
          Choice(0): {Choice(0), Choice(1)},
          Choice(bound.value): {Choice(bound.value), Choice(bound.value - 1)},
        }, reason: '$bound');
      }
    });

    test('at near of 1 fills a choice along an earlier one\'s zigzag at it '
        'or at the distance one either side of it, each in turn, within the '
        'zigzag', () {
      // Each first choice is filled at an edge, the centre or either end, so
      // the second is filled beside one, where a step past an end stays put.
      final int half = 1 << 62;
      for (final Zigzag zigzag in [
        .new(below: 1000, above: 1000),
        .new(below: half, above: Choice.largest.value - half),
      ]) {
        final Map<int, Set<int>> besides = {};
        for (int seed = 0; seed < 200; seed++) {
          final ChoiceSource source = .random(
            .new(seed),
            limit: 2,
            near: .new(1),
            edges: .new(1),
          );
          final int first = source.distance(zigzag);
          (besides[first] ??= {}).add(source.distance(zigzag));
        }
        final int below = -zigzag.below;
        final int above = zigzag.above;
        expect(besides, {
          0: {-1, 0, 1},
          below: {below, below + 1},
          above: {above - 1, above},
        }, reason: '$zigzag');
      }
    });

    test('at a sweep fills a choice that names edges at each in turn, the '
        'first runs that make it, whatever its odds, and as its odds say '
        'after', () {
      final Bound bound = .new(1 << 40);
      final List<Choice> edges = [.new(1), .new(500), .new(999)];
      // Each run fills a choice that names no edge first, so odds of near
      // of 1 fill the named choice beside it, and odds of edges of 1 at one
      // of 0, the bound and the named edges, where the sweep does not.
      for (final (
            String odds,
            Odds near,
            Odds edgeOdds,
            bool Function(Choice earlier, Choice named) asOddsSay,
          )
          in [
            (
              'near of 1',
              .new(1),
              .never,
              (Choice earlier, Choice named) =>
                  (earlier.value - named.value).abs() <= 1,
            ),
            (
              'edges of 1',
              .never,
              .new(1),
              (Choice _, Choice named) =>
                  [Choice(0), Choice(bound.value), ...edges].contains(named),
            ),
          ]) {
        final Sweep sweep = .new();
        final List<(Choice, Choice)> filled = [
          for (int run = 0; run < 4; run++)
            () {
              final ChoiceSource source = .random(
                .new(run),
                limit: 2,
                sweep: sweep,
                near: near,
                edges: edgeOdds,
              );
              return (source.choose(bound), source.choose(bound, edges: edges));
            }(),
        ];
        expect(
          [for (final (_, Choice named) in filled.take(3)) named],
          edges,
          reason: odds,
        );
        final (Choice earlier, Choice named) = filled.last;
        expect(
          asOddsSay(earlier, named),
          isTrue,
          reason: '$odds: $named after $earlier',
        );
      }
    });

    test('at a sweep fills each choice alike of a run at the named edges in '
        'turn, apart from the others', () {
      final Bound bound = .new(9);
      final List<Choice> edges = [.new(4), .new(7)];
      final Sweep sweep = .new();
      final List<List<Choice>> filled = [
        for (int run = 0; run < 2; run++)
          () {
            final ChoiceSource source = .random(
              .new(run),
              limit: 4,
              sweep: sweep,
            );
            return [
              source.choose(bound, edges: edges),
              source.choose(.new(8), edges: edges),
              source.choose(bound, edges: edges),
              source.choose(bound, edges: [.new(4)]),
            ];
          }(),
      ];
      expect(filled, [
        [Choice(4), Choice(4), Choice(4), Choice(4)],
        [Choice(7), Choice(7), Choice(7), filled[1][3]],
      ]);
    });

    test('at a sweep fills a choice that names no edge as it would without '
        'one', () {
      for (int seed = 0; seed < 20; seed++) {
        ChoiceSequence filled({Sweep? sweep}) {
          final ChoiceSource source = .random(
            .new(seed),
            limit: 5,
            sweep: sweep,
            near: .new(0.5),
            edges: .new(0.5),
          );
          source
            ..choose(.new(1000))
            ..choose(.new(1000))
            ..weigh(.new(0.5))
            ..choose(.new(1 << 40))
            ..choose(.new(1000));
          return source.record;
        }

        expect(filled(sweep: .new()), filled(), reason: '$seed');
      }
    });

    test('at near of 1/2 fills a choice beside each earlier one under its '
        'bound alike', () {
      // A bound this wide fills two uniform choices far apart, so a third
      // filled beside one of them is beside exactly one.
      final Bound bound = .new(1 << 40);
      final List<int> beside = [0, 0];
      for (int seed = 0; seed < 1000; seed++) {
        final ChoiceSource source = .random(
          .new(seed),
          limit: 3,
          near: .new(0.5),
        );
        final List<Choice> earlier = [
          source.choose(bound),
          source.choose(bound),
        ];
        if ((earlier[0].value - earlier[1].value).abs() <= 1) continue;
        final Choice third = source.choose(bound);
        for (int i = 0; i < earlier.length; i++) {
          if ((third.value - earlier[i].value).abs() <= 1) beside[i]++;
        }
      }
      // About 250 of the thousand fill the second uniformly and the third
      // beside one, each about 125, its spread about 10.5, so a count past
      // 40 off it is no fill alike.
      for (final int count in beside) {
        expect(count, inInclusiveRange(85, 165), reason: '$beside');
      }
    });

    test(
      'at near of 1 fills a choice under a bound no earlier choice was '
      'asked for under, along a zigzag no earlier choice was asked for '
      'along, or after a weighted choice alone, as it would without near',
      () {
        for (int seed = 0; seed < 20; seed++) {
          ChoiceSequence filled({required Odds near}) {
            final ChoiceSource source = .random(
              .new(seed),
              limit: 5,
              near: near,
              edges: .new(0.5),
            );
            source
              ..choose(.new(1000))
              ..weigh(.new(0.5))
              ..choose(.new(999))
              ..choose(.binary)
              ..distance(.new(below: 500, above: 500));
            return source.record;
          }

          expect(
            filled(near: .new(1)),
            filled(near: .never),
            reason: '$seed',
          );
        }
      },
    );

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

    test('weighs at its own odds whatever its near and its edges', () {
      final ChoiceSource source = .random(
        .new(0),
        limit: 100,
        near: .new(1),
        edges: .new(1),
      );
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
      final ChoiceSource source = .fixed(sequenceOf([]));
      expect(run(source, source.reject), Status.rejected);
    });

    test('stays the source\'s stop where the body caught it and returned', () {
      final ChoiceSource source = .fixed(sequenceOf([]));
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

    // Each stop beside a source whose later choice or weighted choice would
    // be handed over, or stop otherwise, were the source to forget it had
    // stopped, wherever a source can. A later ask that only repeats the
    // stop, another past an overrun or a reject after a reject, stops alike
    // either way, as does a weighted choice above 1 asked again.
    final List<
      (String, Status, ChoiceSource Function(), void Function(ChoiceSource))
    >
    stops = [
      (
        'an overrun',
        .overrun,
        () => .fixed(sequenceOf([])),
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
          expect(source.record, sequenceOf([]));
        });
      }
    }
  });

  group('over every small sequence', () {
    test('A fixed source hands a run exactly its sequence\'s choices in '
        'order, and a run that asks past its end ends overrun.', () {
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

    test('A fixed choice above the bound a generator now asks for ends the '
        'run rejected.', () {
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

    test('A random fill never gives a choice above the bound asked for, nor '
        'more choices than its limit.', () {
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
  });

  group('over every small sequence of asks, at every few odds', () {
    test('An early run never fills a choice outside its bound, whatever fill '
        'it takes.', () {
      // A sweep is kept across the asks, so its later runs fill a choice at
      // its second named edge as well as its first.
      for (int seed = 0; seed < 3; seed++) {
        for (final Odds near in _someOdds) {
          for (final Odds edges in _someOdds) {
            for (final Sweep? sweep in [null, .new()]) {
              for (final ChoiceSequence asks in everySequence(
                length: _length,
                bound: _scaled.length,
              )) {
                final List<(Bound, Choice)> handed = _handedTo(
                  .random(
                    .new(seed),
                    limit: _length,
                    sweep: sweep,
                    near: near,
                    edges: edges,
                  ),
                  asks,
                );
                expect(handed, hasLength(asks.choices.length));
                for (final (Bound bound, Choice choice) in handed) {
                  expect(
                    bound.admits(choice),
                    isTrue,
                    reason:
                        'seed $seed, near $near, edges $edges, sweep '
                        '${sweep != null}, asks $asks: $choice above $bound',
                  );
                }
              }
            }
          }
        }
      }
    });

    test('An early run never fills a distance outside its zigzag, whatever '
        'fill it takes.', () {
      for (int seed = 0; seed < 3; seed++) {
        for (final Odds near in _someOdds) {
          for (final Odds edges in _someOdds) {
            for (int below = 0; below <= _bound; below++) {
              for (int above = 0; above <= _bound; above++) {
                final Zigzag zigzag = .new(below: below, above: above);
                final ChoiceSource source = .random(
                  .new(seed),
                  limit: _length,
                  sweep: .new(),
                  near: near,
                  edges: edges,
                );
                for (int ask = 0; ask < _length; ask++) {
                  expect(
                    source.distance(zigzag),
                    inInclusiveRange(-below, above),
                    reason: 'seed $seed, near $near, edges $edges, $zigzag',
                  );
                }
              }
            }
          }
        }
      }
    });

    test('Naming a choice\'s edges changes no value a given sequence '
        'draws.', () {
      for (int size = 0; size <= _length; size++) {
        final List<ChoiceSequence> sequences = everySequenceOf(
          size: size,
          bound: _bound,
        ).toList();
        for (final ChoiceSequence sequence in sequences) {
          for (final ChoiceSequence bounds in everySequence(
            length: size + 1,
            bound: _bound,
          )) {
            ({ChoiceSequence handed, Status status}) drawn({
              required bool named,
            }) {
              final ChoiceSource source = .fixed(sequence);
              final List<Choice> handed = [];
              final Status status = run(source, () {
                for (final Choice bound in bounds.choices) {
                  handed.add(
                    source.choose(
                      .new(bound.value),
                      edges: named
                          ? [for (int e = 0; e <= bound.value; e++) .new(e)]
                          : const [],
                    ),
                  );
                }
              });
              return (handed: .new(handed), status: status);
            }

            expect(
              drawn(named: true),
              drawn(named: false),
              reason: '$sequence under $bounds',
            );
          }
        }
      }
    });
  });

  group('a bug in grit', () {
    test('an edge named outside its bound is thrown, by either source', () {
      for (final ChoiceSource source in [
        .fixed(sequenceOf([0])),
        .random(.new(0), limit: 1, edges: .new(1)),
      ]) {
        expect(
          () => source.choose(.new(3), edges: [.new(1), .new(4)]),
          throwsArgumentError,
        );
        expect(source.record, sequenceOf([]));
      }
    });

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
        near: draw(_odds, label: 'near'),
        edges: draw(_odds, label: 'edges'),
      );
      final List<_Ask> asks = draw(.list(_ask), label: 'asks');
      final List<(Bound, Choice)> handed = [];
      final Status status = run(source, () {
        for (final _Ask ask in asks) {
          handed.add(switch (ask) {
            _Choose(:final Bound bound, :final List<Choice> edges) => (
              bound,
              source.choose(bound, edges: edges),
            ),
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

    property('An early run never fills a choice outside its bound, whatever '
        'fill it takes.', (Draw draw) {
      // Each odds is drawn from its ends as often as between them, so a run
      // takes each fill alone as well as a mix.
      final Gen<Odds> anyOdds = .oneOf([
        .element([.never, .new(1)]),
        _odds,
      ]);
      final int seed = draw(.integer(min: 0, max: 0xFFFFFFFF), label: 'seed');
      final Odds near = draw(anyOdds, label: 'near');
      final Odds edges = draw(anyOdds, label: 'edges');
      // A sweep kept across a few runs, so a later run fills a choice at a
      // later named edge.
      final Sweep? sweep = draw(.boolean(), label: 'swept') ? .new() : null;
      final int runs = draw(.integer(min: 1, max: 4), label: 'runs');
      // A few bounds, so a later choice is often asked for under an earlier
      // one's.
      final List<Bound> bounds = draw(
        .list(
          anyChoice.map((Choice c) => .new(c.value)),
          minLength: 1,
          maxLength: 3,
        ),
        label: 'bounds',
      );
      final List<(Bound, List<Choice>)> asks = draw(
        .list(
          .build((Draw draw) {
            final Bound bound = draw(.element(bounds));
            return (bound, draw(_edgesWithin(bound)));
          }),
          maxLength: 64,
        ),
        label: 'asks',
      );
      for (int run = 0; run < runs; run++) {
        final ChoiceSource source = .random(
          .new(seed + run),
          limit: 64,
          sweep: sweep,
          near: near,
          edges: edges,
        );
        for (final (Bound bound, List<Choice> named) in asks) {
          final Choice choice = source.choose(bound, edges: named);
          expect(bound.admits(choice), isTrue, reason: '$choice above $bound');
        }
      }
    });

    property('An early run never fills a distance outside its zigzag, '
        'whatever fill it takes.', (Draw draw) {
      final int seed = draw(.integer(min: 0, max: 0xFFFFFFFF), label: 'seed');
      final ChoiceSource source = .random(
        .new(seed),
        limit: 64,
        sweep: draw(.boolean(), label: 'swept') ? .new() : null,
        near: draw(_odds, label: 'near'),
        edges: draw(_odds, label: 'edges'),
      );
      // A few zigzags, so a later distance is often asked for along an
      // earlier one's.
      final List<Zigzag> zigzags = draw(
        .list(anyZigzag, minLength: 1, maxLength: 3),
        label: 'zigzags',
      );
      final List<Zigzag> asks = draw(
        .list(.element(zigzags), maxLength: 64),
        label: 'asks',
      );
      for (final Zigzag zigzag in asks) {
        expect(
          source.distance(zigzag),
          inInclusiveRange(-zigzag.below, zigzag.above),
          reason: '$zigzag',
        );
      }
    });

    property('Naming a choice\'s edges changes no value a given sequence '
        'draws.', (Draw draw) {
      final ChoiceSequence sequence = draw(anySequence, label: 'sequence');
      final List<Bound> bounds = draw(
        .list(anyChoice.map((Choice c) => .new(c.value))),
        label: 'bounds',
      );
      final List<List<Choice>> edges = [
        for (final (int i, Bound bound) in bounds.indexed)
          draw(_edgesWithin(bound), label: 'edges $i'),
      ];
      ({ChoiceSequence handed, Status status}) drawn({required bool named}) {
        final ChoiceSource source = .fixed(sequence);
        final List<Choice> handed = [];
        final Status status = run(source, () {
          for (final (int i, Bound bound) in bounds.indexed) {
            handed.add(
              source.choose(bound, edges: named ? edges[i] : const []),
            );
          }
        });
        return (handed: .new(handed), status: status);
      }

      expect(drawn(named: true), drawn(named: false));
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
