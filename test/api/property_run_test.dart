import 'dart:async';

import 'package:grit/src/api/for_all.dart';
import 'package:grit/src/api/property_run.dart';
import 'package:grit/src/api/settings.dart';
import 'package:grit/src/choice/choice.dart';
import 'package:grit/src/choice/choice_sequence.dart';
import 'package:grit/src/engine/body.dart';
import 'package:grit/src/engine/call_site.dart';
import 'package:grit/src/engine/clock.dart';
import 'package:grit/src/engine/first_found.dart';
import 'package:grit/src/engine/outcome.dart';
import 'package:grit/src/engine/run.dart';
import 'package:grit/src/engine/shrink_end.dart';
import 'package:grit/src/gen/gen.dart';
import 'package:grit/src/report/report.dart';
import 'package:grit/src/store/file_store.dart';
import 'package:grit/src/store/loaded.dart';
import 'package:test/test.dart';

import '../support/bodies.dart';
import '../support/fake_clock.dart';
import '../support/memory_store.dart';
import '../support/small.dart';

/// The call site of every search in this file.
final CallSite _callSite = .of(.current);

/// The search of [settings], the defaults where none are given, from
/// [seed], timed by [clock], a clock that never moves where none is given,
/// and keeping its failure in an empty store.
PropertyRun _run([Settings? settings, Clock? clock, int seed = 0]) => .new(
  settings ?? .new(),
  callSite: _callSite,
  clock: clock ?? FakeClock(),
  store: MemoryStore(),
  seed: seed,
);

/// What a check threw:
///
/// - `error`: the error.
/// - `stackTrace`: where it was thrown.
typedef _Thrown = ({Object error, StackTrace stackTrace});

/// How a check ended:
///
/// - `thrown`: what it threw, or null where it returned.
/// - `printed`: each line it printed, in order.
typedef _Printed = ({_Thrown? thrown, List<String> printed});

/// How [check] ended, with each line it printed.
Future<_Printed> _printed(Future<void> Function() check) async {
  final List<String> printed = [];
  final _Thrown? thrown = await runZoned(
    () => _thrown(check()),
    zoneSpecification: .new(print: (_, _, _, String line) => printed.add(line)),
  );
  return (thrown: thrown, printed: printed);
}

/// A body whose first [rejecting] runs are rejected, and whose every run
/// past them returns.
Body _rejectingFirst(int rejecting) {
  int runs = 0;
  return (Draw draw) => draw.assume(runs++ >= rejecting);
}

/// What [check] throws, or null where it returns.
Future<_Thrown?> _thrown(Future<void> check) async {
  try {
    await check;
  } on Object catch (error, stackTrace) {
    return (error: error, stackTrace: stackTrace);
  }
  return null;
}

/// A body that draws a list of choices from 0 to 3 and fails where it holds
/// at least [key], choice by choice: with a [StateError] from one line where
/// its sum is even, and an [ArgumentError] from another where it is odd.
Body _failingFrom(List<int> key) => (Draw draw) {
  final List<int> xs = draw(.list(.integer(min: 0, max: 3)));
  if (xs.length < key.length) return;
  for (int i = 0; i < key.length; i++) {
    if (xs[i] < key[i]) return;
  }
  if (xs.fold(0, (int sum, int x) => sum + x).isEven) {
    throw StateError('even');
  }
  throw ArgumentError('odd');
};

/// Checks that the token [failed]'s report prints, searched from [seed],
/// replays a run of [body] that fails as [failed]'s did.
Future<void> _expectTokenReplays(Failed failed, Body body, int seed) async {
  final String token = RegExp(r"replay: '([^']*)'")
      .firstMatch(report(failed, seed: seed, settings: 'Settings()'))![1]!;
  final Outcome replayed = await _run(.new(replay: token)).outcome(body);
  expect(
    replayed,
    isA<Reproduced>().having(
      (Reproduced reproduced) => failed.run.failedAlike(reproduced.run),
      'failed alike',
      isTrue,
    ),
    reason: token,
  );
}

void main() {
  group('the defaults', () {
    test('make 100 runs', () async {
      expect(
        await _run().outcome((Draw draw) {}),
        isA<Passed>().having((Passed passed) => passed.runs, 'runs', 100),
      );
    });

    test(
      'give up after 1,000 runs rejected, 10 for each run asked for',
      () async {
        expect(
          await _run().outcome((Draw draw) => draw.assume(false)),
          isA<GaveUp>()
              .having((GaveUp gaveUp) => gaveUp.rejected, 'rejected', 1000)
              .having((GaveUp gaveUp) => gaveUp.overran, 'overran', 0),
        );
      },
    );

    test('give up after 30 runs rejected where 3 are asked for', () async {
      expect(
        await _run(.new(runs: 3)).outcome((Draw draw) => draw.assume(false)),
        isA<GaveUp>().having(
          (GaveUp gaveUp) => gaveUp.rejected,
          'rejected',
          30,
        ),
      );
    });

    test('let a run make 8,192 choices and no more', () async {
      Body drawing(int choices) => (Draw draw) {
        for (int i = 0; i < choices; i++) {
          draw(.boolean());
        }
      };
      expect(await _run().outcome(drawing(8192)), isA<Passed>());
      expect(
        await _run().outcome(drawing(8193)),
        isA<GaveUp>().having(
          (GaveUp gaveUp) => gaveUp.overran,
          'overran',
          1000,
        ),
      );
    });

    test('bound shrinking at 5,000 steps and 10 seconds', () {
      final Settings settings = .new();
      expect(settings.shrinkSteps, 5000);
      expect(settings.shrinkTime, const Duration(seconds: 10));
    });

    test('draw a seed afresh for each search', () {
      expect(Settings().seed, isNull);
      final Set<int> seeds = {
        for (int i = 0; i < 20; i++)
          PropertyRun.of(.new(), callSite: _callSite).seed,
      };
      expect(seeds.length, greaterThan(1));
      expect(seeds, everyElement(inInclusiveRange(0, (1 << 32) - 1)));
    });
  });

  group('the settings', () {
    test('of a run count below 1, or a negative step or time bound, are thrown '
        'as a bug', () {
      expect(() => Settings(runs: 0), throwsRangeError);
      expect(
        () => Settings(shrinkSteps: -1),
        throwsA(
          isA<RangeError>().having(
            (RangeError error) => error.name,
            'name',
            'shrinkSteps',
          ),
        ),
      );
      expect(
        () => Settings(shrinkTime: const .new(microseconds: -1)),
        throwsA(
          isA<RangeError>().having(
            (RangeError error) => error.name,
            'name',
            'shrinkTime',
          ),
        ),
      );
      expect(Settings(shrinkTime: .zero).shrinkTime, Duration.zero);
    });

    test('name the seed a search fills from', () {
      expect(PropertyRun.of(.new(seed: 5), callSite: _callSite).seed, 5);
    });

    test('fill the same draws from the same seed', () async {
      Future<Object?> drawn(int seed) async {
        // Each search keeps its failure in a store of its own, so neither
        // starts from the other's.
        final Outcome outcome = await _run(.new(shrinkSteps: 0), null, seed)
            .outcome((Draw draw) {
              draw(.list(.integer()));
              throw StateError('drawn');
            });
        return switch (outcome) {
          Failed(:final Threw run) => run.draws.single.value,
          Passed() ||
          Flaky() ||
          GaveUp() ||
          Reproduced() ||
          NotReproduced() => fail(
            'Seed $seed came to ${outcome.runtimeType}, where a failure was '
            'due',
          ),
        };
      }

      expect(await drawn(3), await drawn(3));
    });

    test('bound shrinking by their steps', () async {
      expect(
        await _run(.new(shrinkSteps: 0)).outcome(failsOnTrue),
        isA<Failed>()
            .having((Failed failed) => failed.end, 'end', ShrinkEnd.steps)
            .having((Failed failed) => failed.steps, 'steps', 0),
      );
    });

    test('bound shrinking by their time', () async {
      expect(
        await _run(
          .new(shrinkTime: const .new(seconds: 1)),
          FakeClock([const .new(seconds: 1)]),
        ).outcome(failsOnTrue),
        isA<Failed>().having(
          (Failed failed) => failed.end,
          'end',
          ShrinkEnd.time,
        ),
      );
    });
  });

  group('a replay token', () {
    test('that is no token is thrown at the settings\' construction as an '
        'argument error saying so', () {
      for (final String text in ['', 'grit1:01', 'grit1:0 ', '[1, 3]']) {
        expect(
          () => Settings(replay: text),
          throwsA(
            isA<ArgumentError>()
                .having((e) => e.name, 'name', 'replay')
                .having((e) => e.message, 'message', 'is no grit token')
                .having((e) => e.invalidValue, 'invalidValue', text),
          ),
          reason: text,
        );
      }
    });

    test('of another format is thrown at the settings\' construction as an '
        'argument error naming its format', () {
      expect(
        () => Settings(replay: 'grit2:3'),
        throwsA(
          isA<ArgumentError>()
              .having((e) => e.name, 'name', 'replay')
              .having(
                (e) => e.message,
                'message',
                'is a token of format `grit2`, and this grit reads `grit1` '
                    'alone',
              )
              .having((e) => e.invalidValue, 'invalidValue', 'grit2:3'),
        ),
      );
    });

    test('replays its case alone, failing where it throws', () async {
      int runs = 0;
      final Outcome outcome = await _run(.new(replay: 'grit1:1'))
          .outcome((Draw draw) {
            runs++;
            failsOnTrue(draw);
          });
      expect(
        outcome,
        isA<Reproduced>().having((o) => o.run.record.choices, 'choices', [
          Choice(1),
        ]),
      );
      expect(runs, 1);
    });

    test('that no longer fails is not reproduced', () async {
      expect(
        await _run(.new(replay: 'grit1:0')).outcome(failsOnTrue),
        isA<NotReproduced>().having((o) => o.run, 'run', isA<Returned>()),
      );
    });
  });

  group('the store', () {
    test('keeps a failure under .dart_tool/grit/, which the next search at '
        'its call site replays first', () async {
      final CallSite callSite = .of(.current);
      final FileStore store = .new(.new('.dart_tool/grit'));
      final List<Outcome> outcomes = [
        for (int search = 0; search < 2; search++)
          await PropertyRun.of(.new(), callSite: callSite).outcome(failsOnTrue),
      ];
      expect(
        outcomes.last,
        isA<Failed>().having(
          (o) => o.firstFound,
          'firstFound',
          FirstFound.stored,
        ),
      );
      expect(
        store.load(callSite.key),
        isA<Stored>().having(
          (Stored stored) => stored.sequence,
          'sequence',
          (outcomes.last as Failed).sequence,
        ),
      );
    });
  });

  group('a check', () {
    test('of a passed outcome returns, printing nothing', () async {
      final (:_Thrown? thrown, :List<String> printed) = await _printed(
        () => _run().check((Draw draw) {}),
      );
      expect(thrown, isNull);
      expect(printed, isEmpty);
    });

    test('of a passed outcome that warns prints its report under its test, '
        'and returns', () async {
      final PropertyRun run = _run(
        .new(runs: 2),
        FakeClock([const .new(minutes: 1)]),
      );
      final (:_Thrown? thrown, :List<String> printed) = await _printed(
        () => run.check(_rejectingFirst(3)),
      );
      expect(thrown, isNull);
      expect(printed, [
        allOf(
          startsWith(
            'The property passed 2 runs.\n'
            '\n'
            'Warning: the property is slow. Its runs took 12.0 s each on '
            'average, so a search of 2 runs takes about 24.0 s. A lower `runs` '
            'setting makes it faster.\n'
            '\n'
            'Warning: most of the property\'s runs were invalid, 3 rejected '
            'and 0 overrun against 2 returned.',
          ),
          endsWith(
            'Seed 0. Repeat this search with '
            '`settings: Settings(seed: 0, runs: 2)`.',
          ),
        ),
      ]);
    });

    test('of a failure first found from the store names no seed as '
        'repeating its search', () async {
      final Map<String, Body> bodies = {
        'failed': failsOnTrue,
        'flaky': failsOnce(),
      };
      for (final MapEntry(key: String kind, value: Body body)
          in bodies.entries) {
        final PropertyRun run = .new(
          .new(),
          callSite: _callSite,
          clock: FakeClock(),
          store: MemoryStore({
            _callSite.key: Stored(sequenceOf([1])),
          }),
          seed: 7,
        );
        final _Thrown? thrown = await _thrown(run.check(body));
        expect(
          thrown?.error,
          isA<TestFailure>().having(
            (TestFailure failure) => failure.message,
            'message',
            allOf(
              contains(
                'first found by replaying the failure an earlier '
                'search stored',
              ),
              isNot(contains('Seed')),
            ),
          ),
          reason: kind,
        );
      }
    });

    test('of a failed outcome carries its warnings in its report, printing '
        'none', () async {
      final PropertyRun run = _run(null, FakeClock([const .new(minutes: 1)]));
      final (:_Thrown? thrown, :List<String> printed) = await _printed(
        () => run.check(failsOnTrue),
      );
      expect(printed, isEmpty);
      expect(
        thrown?.error,
        isA<TestFailure>().having(
          (TestFailure failure) => failure.message,
          'message',
          contains('\n\nWarning: the property is slow. '),
        ),
      );
    });

    test(
      'of a failed outcome throws its report with the run\'s stack',
      () async {
        // Each search keeps its failure in a store of its own, so the check
        // does not start from the outcome's failure.
        final Outcome outcome = await _run().outcome(failsOnTrue);
        final _Thrown? thrown = await _thrown(_run().check(failsOnTrue));
        expect(
          thrown?.error,
          isA<TestFailure>().having(
            (TestFailure failure) => failure.message,
            'message',
            report(outcome, seed: 0, settings: 'Settings(seed: 0)'),
          ),
        );
        expect(
          thrown?.stackTrace.toString(),
          startsWith('#0      failsOnTrue '),
        );
      },
    );

    test('of a failed outcome reports each value as the draw returned it, '
        'not as the body left it', () async {
      final _Thrown? thrown = await _thrown(
        _run().check((Draw draw) {
          final List<int> xs = draw(
            .list(.integer(min: 0, max: 1), minLength: 2, maxLength: 2),
            label: 'xs',
          );
          if (xs case [0, 1]) {
            xs
              ..sort((int a, int b) => b.compareTo(a))
              ..add(99);
            throw StateError('drawn [0, 1]');
          }
        }),
      );
      expect(
        thrown?.error,
        isA<TestFailure>().having(
          (TestFailure failure) => failure.message,
          'message',
          contains('It drew:\n  xs: [0, 1]\n\n'),
        ),
      );
    });

    test('of a failed outcome prints a drawn string quoted, so its '
        'whitespace shows', () async {
      final _Thrown? thrown = await _thrown(
        _run().check((Draw draw) {
          final String text = draw(.string(alphabet: .of('a ')), label: 'text');
          if (text.contains(' ')) throw StateError('a space');
        }),
      );
      expect(
        thrown?.error,
        isA<TestFailure>().having(
          (TestFailure failure) => failure.message,
          'message',
          contains("It drew:\n  text: ' '\n\n"),
        ),
      );
    });

    test(
      'of a flaky outcome throws its report with the failure\'s stack',
      () async {
        final _Thrown? thrown = await _thrown(_run().check(failsOnce()));
        expect(
          thrown?.error,
          isA<TestFailure>().having(
            (TestFailure failure) => failure.message,
            'message',
            startsWith('The property is flaky'),
          ),
        );
        expect(thrown?.stackTrace.toString(), startsWith('#0      failsOnce.'));
      },
    );

    test(
      'reports the settings it searched under, filled from its seed',
      () async {
        expect(
          (await _thrown(
            _run(.new(runs: 3, shrinkSteps: 0))
                .check((Draw draw) => draw.assume(false)),
          ))?.error,
          isA<TestFailure>().having(
            (TestFailure failure) => failure.message,
            'message',
            endsWith(
              'Seed 0. Repeat this search with '
              '`settings: Settings(seed: 0, runs: 3, shrinkSteps: 0)`.',
            ),
          ),
        );
      },
    );

    test(
      'of a reproduced outcome throws its report with the run\'s stack',
      () async {
        final _Thrown? thrown = await _thrown(
          _run(.new(replay: 'grit1:1')).check(failsOnTrue),
        );
        expect(
          thrown?.error,
          isA<TestFailure>().having(
            (TestFailure failure) => failure.message,
            'message',
            startsWith(
              'The property failed on the case its replay token names',
            ),
          ),
        );
        expect(
          thrown?.stackTrace.toString(),
          startsWith('#0      failsOnTrue '),
        );
      },
    );

    test('of a not-reproduced outcome throws its report', () async {
      expect(
        (await _thrown(_run(.new(replay: 'grit1:0')).check(failsOnTrue)))
            ?.error,
        isA<TestFailure>().having(
          (TestFailure failure) => failure.message,
          'message',
          'The replay token no longer reproduces a failure: run once, it '
              'returned.\n'
              '\n'
              'Remove `replay` from the settings to search for a failure '
              'again.',
        ),
      );
    });

    test('of a gave-up outcome throws its report', () async {
      expect(
        (await _thrown(_run().check((Draw draw) => draw.assume(false))))?.error,
        isA<TestFailure>().having(
          (TestFailure failure) => failure.message,
          'message',
          report(
            GaveUp(rejected: 1000, overran: 0),
            seed: 0,
            settings: 'Settings(seed: 0)',
          ),
        ),
      );
    });
  });
  group('over every small body, each from a few seeds', () {
    test('The token a failure\'s report prints replays a run that fails as '
        'the reported one did.', () async {
      final Set<Type> errors = {};
      for (final ChoiceSequence key in everySequence(length: 2, bound: 3)) {
        final Body body = _failingFrom([
          for (final Choice choice in key.choices) choice.value,
        ]);
        for (int seed = 0; seed < 3; seed++) {
          if (await _run(null, null, seed).outcome(body)
              case final Failed failed) {
            errors.add(failed.run.failure.type);
            await _expectTokenReplays(failed, body, seed);
          }
        }
      }
      expect(errors, {StateError, ArgumentError});
    });
  });

  group('on grit, over larger inputs', () {
    test('The token a failure\'s report prints replays a run that fails as '
        'the reported one did.', () async {
      int failed = 0;
      await forAll((Draw draw) async {
        final Body body = _failingFrom(
          draw(.list(.integer(min: 0, max: 3), maxLength: 4), label: 'key'),
        );
        final int seed = draw(.integer(min: 0, max: 0xFFFFFFFF), label: 'seed');
        if (await _run(null, null, seed).outcome(body)
            case final Failed found) {
          failed++;
          await _expectTokenReplays(found, body, seed);
        }
      });
      expect(failed, greaterThan(0));
    });
  });
}
