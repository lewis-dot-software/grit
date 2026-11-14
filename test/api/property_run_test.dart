import 'package:grit/src/api/property_run.dart';
import 'package:grit/src/api/settings.dart';
import 'package:grit/src/engine/body.dart';
import 'package:grit/src/engine/call_site.dart';
import 'package:grit/src/engine/clock.dart';
import 'package:grit/src/engine/outcome.dart';
import 'package:grit/src/engine/run.dart';
import 'package:grit/src/engine/shrink_end.dart';
import 'package:grit/src/gen/gen.dart';
import 'package:grit/src/report/report.dart';
import 'package:test/test.dart';

import '../support/bodies.dart';
import '../support/fake_clock.dart';

/// The call site of every search in this file.
final CallSite _callSite = .of(.current);

/// The search of [settings], the defaults where none are given, from seed 0,
/// timed by [clock], a clock that never moves where none is given.
PropertyRun _run([Settings? settings, Clock? clock]) => .new(
  settings ?? .new(),
  callSite: _callSite,
  clock: clock ?? FakeClock(),
  seed: 0,
);

/// What [check] throws, or null where it returns.
Future<(Object, StackTrace)?> _thrown(Future<void> check) async {
  try {
    await check;
  } on Object catch (error, stackTrace) {
    return (error, stackTrace);
  }
  return null;
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
      expect(() => Settings(shrinkSteps: -1), throwsRangeError);
      expect(
        () => Settings(shrinkTime: const .new(microseconds: -1)),
        throwsRangeError,
      );
      expect(Settings(shrinkTime: .zero).shrinkTime, Duration.zero);
    });

    test('name the seed a search fills from', () {
      expect(PropertyRun.of(.new(seed: 5), callSite: _callSite).seed, 5);
    });

    test('fill the same draws from the same seed', () async {
      Future<Object?> drawn(int seed) async {
        final Outcome outcome =
            await PropertyRun.of(
              .new(seed: seed, shrinkSteps: 0),
              callSite: _callSite,
            ).outcome((Draw draw) {
              draw(.list(.integer()));
              throw StateError('drawn');
            });
        return switch (outcome) {
          Failed(:final Threw run) => run.draws.single.value,
          Passed() || Flaky() || GaveUp() => fail(
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

  group('a check', () {
    test('of a passed outcome returns', () async {
      expect(await _thrown(_run().check((Draw draw) {})), isNull);
    });

    test(
      'of a failed outcome throws its report with the run\'s stack',
      () async {
        final PropertyRun run = _run();
        final Outcome outcome = await run.outcome(failsOnTrue);
        final (Object, StackTrace)? thrown = await _thrown(
          run.check(failsOnTrue),
        );
        expect(
          thrown?.$1,
          isA<TestFailure>().having(
            (TestFailure failure) => failure.message,
            'message',
            report(outcome, seed: 0, settings: 'Settings(seed: 0)'),
          ),
        );
        expect(thrown?.$2.toString(), startsWith('#0      failsOnTrue '));
      },
    );

    test('of a failed outcome reports each value as the draw returned it, '
        'not as the body left it', () async {
      final (Object, StackTrace)? thrown = await _thrown(
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
        thrown?.$1,
        isA<TestFailure>().having(
          (TestFailure failure) => failure.message,
          'message',
          contains('It drew:\n  xs: [0, 1]\n\n'),
        ),
      );
    });

    test(
      'of a flaky outcome throws its report with the failure\'s stack',
      () async {
        final (Object, StackTrace)? thrown = await _thrown(
          _run().check(failsOnce()),
        );
        expect(
          thrown?.$1,
          isA<TestFailure>().having(
            (TestFailure failure) => failure.message,
            'message',
            startsWith('The property is flaky'),
          ),
        );
        expect(thrown?.$2.toString(), startsWith('#0      failsOnce.'));
      },
    );

    test(
      'reports the settings it searched under, filled from its seed',
      () async {
        expect(
          (await _thrown(
            _run(.new(runs: 3, shrinkSteps: 0))
                .check((Draw draw) => draw.assume(false)),
          ))?.$1,
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

    test('of a gave-up outcome throws its report', () async {
      expect(
        (await _thrown(_run().check((Draw draw) => draw.assume(false))))?.$1,
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
}
