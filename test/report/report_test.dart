import 'package:grit/grit.dart';
import 'package:grit/src/report/report.dart';
import 'package:test/test.dart';

import '../support/outcomes.dart';
import '../support/small.dart';
import '../support/threw.dart';

/// A failed outcome of [run], whose shrinking ended on [end] after [steps]
/// steps over [time].
Failed _failed(
  Threw run, {
  ShrinkEnd end = .shrunk,
  int steps = 12,
  Duration time = const .new(milliseconds: 34),
}) => .new(
  run.record,
  run,
  firstFound: .generated,
  steps: steps,
  time: time,
  end: end,
);

/// The Dart of the default settings filled from seed 7.
const String _settings = 'Settings(seed: 7)';

/// A section of a report:
///
/// - `written`: what the run wrote to it.
/// - `part`: the section as printed, or null where none was.
typedef _Section = ({String written, String? part});

void main() {
  group('an outcome', () {
    test('passed reports its run count', () {
      expect(
        report(Passed(runs: 100), seed: 7, settings: _settings),
        'The property passed 100 runs.\n'
        '\n'
        'Seed 7. Repeat this search with `settings: Settings(seed: 7)`.',
      );
    });

    test('failed reports its smallest case, its shrinking, its token and its '
        'seed', () {
      final Threw run = threw(
        draws: [
          (label: 'xs', value: [3], text: '[3]'),
          (label: null, value: true, text: 'true'),
        ],
        notes: ['sum 3'],
      );
      expect(
        report(_failed(run), seed: 7, settings: _settings),
        'The property failed. Its smallest failing case, shrunk in 12 steps '
        'over 34 ms:\n'
        '\n'
        'It drew:\n'
        '  xs: [3]\n'
        '  true\n'
        '\n'
        'It noted:\n'
        '  sum 3\n'
        '\n'
        'It threw:\n'
        '  Bad state: too big\n'
        '\n'
        'Replay this case alone with '
        '`settings: Settings(replay: \'grit1:1.3.0\')`.\n'
        '\n'
        'Seed 7. The next search at this call site replays this failure '
        'first, so `settings: Settings(seed: 7)` repeats this search once '
        '`.dart_tool/grit/` no longer holds it.',
      );
    });

    test('failed from the store says it was first found there, and that the '
        'next search replays it first, with no seed', () {
      final Threw run = threw();
      expect(
        report(
          Failed(
            run.record,
            run,
            firstFound: .stored,
            steps: 12,
            time: const .new(milliseconds: 34),
            end: .shrunk,
          ),
          seed: 7,
          settings: _settings,
        ),
        'The property failed. Its smallest failing case, shrunk in 12 steps '
        'over 34 ms:\n'
        '\n'
        'It drew nothing.\n'
        '\n'
        'It threw:\n'
        '  Bad state: too big\n'
        '\n'
        'It was first found by replaying the failure an earlier search '
        'stored for this call site.\n'
        '\n'
        'Replay this case alone with '
        '`settings: Settings(replay: \'grit1:1.3.0\')`.\n'
        '\n'
        'The next search at this call site replays this failure first.',
      );
    });

    test('flaky from the store says it was first found there, and that the '
        'next search generates afresh, with no seed', () {
      final Threw failed = threw();
      expect(
        report(
          Flaky(
            failed,
            Returned(failed.record, const [], const []),
            firstFound: .stored,
          ),
          seed: 7,
          settings: _settings,
        ),
        endsWith(
          '  Bad state: too big\n'
          '\n'
          'It was first found by replaying the failure an earlier search '
          'stored for this call site.\n'
          '\n'
          'Run again, it returned.\n'
          '\n'
          'The search deleted the failure stored for this call site, so the '
          'next search generates its runs afresh.',
        ),
      );
    });

    test('reproduced reports its case, unshrunk, and how to search again, '
        'with no seed', () {
      final Threw run = threw(
        draws: [(label: 'x', value: 2, text: '2')],
        notes: ['x is 2'],
      );
      expect(
        report(Reproduced(run), seed: 7, settings: _settings),
        'The property failed on the case its replay token names, run once '
        'with no shrinking:\n'
        '\n'
        'It drew:\n'
        '  x: 2\n'
        '\n'
        'It noted:\n'
        '  x is 2\n'
        '\n'
        'It threw:\n'
        '  Bad state: too big\n'
        '\n'
        'Remove `replay` from the settings to search for a failure again.',
      );
    });

    test('not reproduced reports how its run ended, and how to search '
        'again, with no seed', () {
      final ChoiceSequence record = sequenceOf([1]);
      final Map<Run, String> ended = {
        Returned(record, const [], const []): 'it returned.',
        Rejected(record, const [], const []): 'it was rejected.',
        Overran(record, const [], const []):
            'it made more choices than its case holds.',
      };
      for (final MapEntry(key: Run run, value: String end) in ended.entries) {
        expect(
          report(NotReproduced(run), seed: 7, settings: _settings),
          'The replay token no longer reproduces a failure: run once, $end\n'
          '\n'
          'Remove `replay` from the settings to search for a failure again.',
        );
      }
    });

    test('flaky reports its failure and how its replay ended', () {
      final Threw failed = threw(draws: [(label: 'x', value: 2, text: '2')]);
      final Run replay = Returned(failed.record, const [], const []);
      expect(
        report(
          Flaky(failed, replay, firstFound: .generated),
          seed: 7,
          settings: _settings,
        ),
        'The property is flaky: it failed, then did not fail the same way '
        'when its failing case ran again.\n'
        '\n'
        'It drew:\n'
        '  x: 2\n'
        '\n'
        'It threw:\n'
        '  Bad state: too big\n'
        '\n'
        'Run again, it returned.\n'
        '\n'
        'Seed 7. Repeat this search with `settings: Settings(seed: 7)`.',
      );
    });

    test('gave up reports its rejected and overrun counts', () {
      expect(
        report(
          GaveUp(rejected: 990, overran: 10),
          seed: 7,
          settings: _settings,
        ),
        'The property gave up: 990 runs were rejected and 10 overran before '
        'enough returned. A run is rejected by an assume that is false, a '
        'filter that finds no value or a set that finds too few distinct '
        'elements, and overruns where it makes more choices than one run '
        'may.\n'
        '\n'
        'Seed 7. Repeat this search with `settings: Settings(seed: 7)`.',
      );
    });

    test('ends on the settings it was searched under', () {
      expect(
        report(
          Passed(runs: 1000),
          seed: 7,
          settings: 'Settings(seed: 7, runs: 1000)',
        ),
        endsWith(
          'Seed 7. Repeat this search with '
          '`settings: Settings(seed: 7, runs: 1000)`.',
        ),
      );
    });

    test('passed in 1 run says so', () {
      expect(
        report(Passed(runs: 1), seed: 7, settings: _settings),
        startsWith('The property passed 1 run.\n'),
      );
    });

    test('gave up with 1 run rejected says so', () {
      expect(
        report(GaveUp(rejected: 1, overran: 9), seed: 7, settings: _settings),
        startsWith('The property gave up: 1 run was rejected and 9 overran '),
      );
    });
  });

  group('the warnings', () {
    test('of a stored failure that decodes to no sequence say why, and that '
        'it was deleted', () {
      final Map<Undecodable, String> why = {
        NotAToken(): 'is no grit token',
        OtherFormat('grit0'):
            'is a token of format `grit0`, and this grit reads `grit1` alone',
      };
      for (final MapEntry(key: Undecodable reason, value: String text)
          in why.entries) {
        expect(
          report(
            Passed(runs: 100, warnings: [UnreadableStored(reason)]),
            seed: 7,
            settings: _settings,
          ),
          'The property passed 100 runs.\n'
          '\n'
          'Warning: the failure stored for this call site $text, so the '
          'search deleted it and generated its runs afresh.\n'
          '\n'
          'Seed 7. Repeat this search with `settings: Settings(seed: 7)`.',
        );
      }
    });

    test('of a slow property name its time per run and what its run count '
        'costs', () {
      expect(
        report(
          Passed(
            runs: 100,
            warnings: [
              SlowProperty(perRun: const .new(milliseconds: 120), runs: 100),
            ],
          ),
          seed: 7,
          settings: _settings,
        ),
        'The property passed 100 runs.\n'
        '\n'
        'Warning: the property is slow. Its runs took 120 ms each on average, '
        'so a search of 100 runs takes about 12.0 s. A lower `runs` setting '
        'makes it faster, and an `expectedRunTime` setting declares runs this '
        'slow expected.\n'
        '\n'
        'Seed 7. Repeat this search with `settings: Settings(seed: 7)`.',
      );
    });

    test('of mostly invalid runs count each kind', () {
      expect(
        report(
          Passed(
            runs: 10,
            warnings: [MostlyInvalid(returned: 10, rejected: 12, overran: 3)],
          ),
          seed: 7,
          settings: _settings,
        ),
        'The property passed 10 runs.\n'
        '\n'
        'Warning: most of the property\'s runs were invalid, 12 rejected and '
        '3 overrun against 10 returned. A run is rejected by an assume that '
        'is false, a filter that finds no value or a set that finds too few '
        'distinct elements, and overruns where it makes more choices than one '
        'run may.\n'
        '\n'
        'Seed 7. Repeat this search with `settings: Settings(seed: 7)`.',
      );
    });

    test('follow a failed outcome\'s case, one per paragraph, before its '
        'token and its seed', () {
      final Threw run = threw();
      expect(
        report(
          Failed(
            run.record,
            run,
            firstFound: .generated,
            steps: 12,
            time: const .new(milliseconds: 34),
            end: .shrunk,
            warnings: [
              SlowProperty(perRun: const .new(seconds: 1), runs: 100),
              MostlyInvalid(returned: 0, rejected: 1, overran: 0),
            ],
          ),
          seed: 7,
          settings: _settings,
        ),
        endsWith(
          'It threw:\n'
          '  Bad state: too big\n'
          '\n'
          'Warning: the property is slow. Its runs took 1.0 s each on '
          'average, so a search of 100 runs takes about 100.0 s. A lower '
          '`runs` setting makes it faster, and an `expectedRunTime` setting '
          'declares runs this slow expected.\n'
          '\n'
          'Warning: most of the property\'s runs were invalid, 1 rejected and '
          '0 overrun against 0 returned. A run is rejected by an assume that '
          'is false, a filter that finds no value or a set that finds too few '
          'distinct elements, and overruns where it makes more choices than '
          'one run may.\n'
          '\n'
          'Replay this case alone with '
          '`settings: Settings(replay: \'grit1:1.3.0\')`.\n'
          '\n'
          'Seed 7. The next search at this call site replays this failure '
          'first, so `settings: Settings(seed: 7)` repeats this search once '
          '`.dart_tool/grit/` no longer holds it.',
        ),
      );
    });

    test('name a time under a millisecond in microseconds', () {
      expect(
        report(
          GaveUp(
            rejected: 1,
            overran: 0,
            warnings: [
              SlowProperty(perRun: const .new(microseconds: 300), runs: 20000),
            ],
          ),
          seed: 7,
          settings: _settings,
        ),
        contains(
          'Its runs took 300 µs each on average, so a search of 20000 '
          'runs takes about 6.0 s.',
        ),
      );
    });
  });

  group('a failed outcome', () {
    test('whose step budget ran out says its case is the smallest found', () {
      expect(
        report(
          _failed(threw(), end: .steps, steps: 5000),
          seed: 7,
          settings: _settings,
        ),
        startsWith(
          'The property failed. Shrinking ran out of steps after 5000 steps, '
          'over 34 ms, so its failing case is the smallest found within the '
          'budget:\n',
        ),
      );
    });

    test('whose time budget ran out says its case is the smallest found', () {
      expect(
        report(
          _failed(threw(), end: .time, steps: 1, time: .new(seconds: 10)),
          seed: 7,
          settings: _settings,
        ),
        startsWith(
          'The property failed. Shrinking ran out of time after 10.0 s, in '
          '1 step, so its failing case is the smallest found within the '
          'budget:\n',
        ),
      );
    });

    test('that shrank in under a millisecond names its time in microseconds', () {
      expect(
        report(
          _failed(threw(), time: const .new(microseconds: 345)),
          seed: 7,
          settings: _settings,
        ),
        startsWith(
          'The property failed. Its smallest failing case, shrunk in 12 steps '
          'over 345 µs:\n',
        ),
      );
    });

    test('prints each value\'s text as it was drawn, not the value as the '
        'body left it', () {
      final Threw run = threw(
        draws: [
          (label: 'xs', value: [1, 0, 99], text: '[0, 1]'),
          (label: null, value: [5, 99], text: '[5]'),
        ],
      );
      expect(
        report(_failed(run), seed: 7, settings: _settings),
        contains('It drew:\n  xs: [0, 1]\n  [5]\n\n'),
      );
    });

    test('that drew nothing says so', () {
      expect(
        report(_failed(threw()), seed: 7, settings: _settings),
        contains('It drew nothing.'),
      );
    });

    test('indents every line of a value and an error that is not empty '
        'under its heading', () {
      final Threw run = threw(
        draws: [(label: 'text', value: 'one\ntwo', text: 'one\ntwo')],
        message: 'first\nsecond\n',
      );
      expect(
        report(_failed(run), seed: 7, settings: _settings),
        contains(
          'It drew:\n'
          '  text: one\n'
          '  two\n'
          '\n'
          'It threw:\n'
          '  Bad state: first\n'
          '  second\n'
          '\n',
        ),
      );
    });

    test('prints a value and a note ending in a newline with no line of '
        'spaces', () {
      final Threw run = threw(
        draws: [(label: 'body', value: 'x\n', text: 'x\n')],
        notes: ['body x\n'],
      );
      expect(
        report(_failed(run), seed: 7, settings: _settings),
        contains(
          'It drew:\n'
          '  body: x\n'
          '\n'
          'It noted:\n'
          '  body x\n'
          '\n'
          'It threw:\n',
        ),
      );
    });

    test('leaves an empty line inside a value, a note or an error empty', () {
      final Threw run = threw(
        draws: [(label: null, value: 'one\n\ntwo', text: 'one\n\ntwo')],
        notes: ['three\n\nfour'],
        message: 'five\n\nsix',
      );
      expect(
        report(_failed(run), seed: 7, settings: _settings),
        contains(
          'It drew:\n'
          '  one\n'
          '\n'
          '  two\n'
          '\n'
          'It noted:\n'
          '  three\n'
          '\n'
          '  four\n'
          '\n'
          'It threw:\n'
          '  Bad state: five\n'
          '\n'
          '  six\n',
        ),
      );
    });
  });

  group('on grit, over larger inputs', () {
    property('RUN-1: A report says its seed repeats the search only '
        'where that search generated from the seed.', (Draw draw) {
      final Outcome outcome = draw(outcomes);
      final int seed = draw(.integer(min: 0, max: 0xFFFFFFFF), label: 'seed');
      final bool generated = switch (outcome) {
        Passed() || GaveUp() => true,
        Failed(:final FirstFound firstFound) ||
        Flaky(:final FirstFound firstFound) => switch (firstFound) {
          .generated => true,
          .stored => false,
        },
        Reproduced() || NotReproduced() => false,
      };
      final String printed = report(
        outcome,
        seed: seed,
        settings: 'Settings(seed: $seed)',
      );
      expect(printed.contains('Seed $seed.'), generated, reason: printed);
    });

    /// A text over letters, spaces and newlines, which a report indents.
    final Gen<String> text = .string(alphabet: .of('a \n'), maxLength: 8);

    property("RUN-2: Whatever a note's or a drawn value's text holds, "
        'the report prints it: under its heading line for line, two '
        'spaces opening each line that is not empty, with its '
        'trailing whitespace trimmed and no line the indent alone.', (
      Draw draw,
    ) {
      final String drawn = draw(text, label: 'drawn');
      final String noted = draw(text, label: 'noted');
      final String printed = report(
        _failed(
          threw(
            draws: [(label: null, value: drawn, text: drawn)],
            notes: [noted],
          ),
        ),
        seed: 7,
        settings: _settings,
      );
      final RegExpMatch parts = RegExp(
        r'It drew:\n(.*)\n\nIt noted:\n(.*)\n\nIt threw:',
        dotAll: true,
      ).firstMatch(printed)!;
      for (final (:String written, :String? part) in <_Section>[
        (written: drawn, part: parts[1]),
        (written: noted, part: parts[2]),
      ]) {
        final List<String> lines = part!.split('\n');
        expect(lines, everyElement(isNot('  ')));
        expect(lines, everyElement(anyOf(isEmpty, startsWith('  '))));
        expect(
          lines
              .map((String line) => line.isEmpty ? line : line.substring(2))
              .join('\n'),
          written.trimRight(),
        );
      }
    });
  });

  group('a flaky replay', () {
    final Threw failed = threw();

    test('rejected says so', () {
      expect(
        report(
          Flaky(
            failed,
            Rejected(failed.record, [], []),
            firstFound: .generated,
          ),
          seed: 7,
          settings: _settings,
        ),
        contains('Run again, it was rejected.'),
      );
    });

    test('overrun says so', () {
      expect(
        report(
          Flaky(failed, Overran(failed.record, [], []), firstFound: .generated),
          seed: 7,
          settings: _settings,
        ),
        contains('Run again, it made more choices than its case holds.'),
      );
    });

    test('that threw another way names its error and frame', () {
      expect(
        report(
          Flaky(failed, threwOtherwise, firstFound: .generated),
          seed: 7,
          settings: _settings,
        ),
        contains(
          'Run again, it threw another way, ArgumentError from '
          'file:///a_test.dart:9:\n'
          '  Invalid argument(s): odd\n',
        ),
      );
    });

    test('that threw another way indents its error with no line of spaces '
        'from a trailing newline', () {
      final Threw other = .new(
        failed.record,
        const [],
        const [],
        error: StateError('first\nsecond\n'),
        stackTrace: .empty,
        failure: .new(StateError, const []),
      );
      expect(
        report(
          Flaky(failed, other, firstFound: .generated),
          seed: 7,
          settings: _settings,
        ),
        contains(
          ':\n'
          '  Bad state: first\n'
          '  second\n'
          '\n'
          'Seed 7.',
        ),
      );
    });

    test('that threw from no frame grit reads says so', () {
      final Threw other = .new(
        failed.record,
        const [],
        const [],
        error: ArgumentError('odd'),
        stackTrace: .empty,
        failure: .new(ArgumentError, const []),
      );
      expect(
        report(
          Flaky(failed, other, firstFound: .generated),
          seed: 7,
          settings: _settings,
        ),
        contains('ArgumentError from a stack grit could not read:'),
      );
    });

    test('that threw from a frame with no line names its member', () {
      final Threw other = .new(
        failed.record,
        const [],
        const [],
        error: ArgumentError('odd'),
        stackTrace: .empty,
        failure: .new(ArgumentError, [
          .new('snap', .parse('file:///a_test.dart'), null),
        ]),
      );
      expect(
        report(
          Flaky(failed, other, firstFound: .generated),
          seed: 7,
          settings: _settings,
        ),
        contains('ArgumentError from file:///a_test.dart, in snap:'),
      );
    });
  });
}
