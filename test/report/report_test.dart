import 'package:grit/grit.dart';
import 'package:grit/src/report/report.dart';
import 'package:test/test.dart';

import '../support/small.dart';

/// A run that threw a [StateError] of [message] from line 7 of a test, having
/// drawn [draws] and noted [notes].
Threw _threw({
  List<Drawn> draws = const [],
  List<String> notes = const [],
  String message = 'too big',
}) => .new(
  sequenceOf([1, 3, 0]),
  draws,
  notes,
  error: StateError(message),
  stackTrace: .empty,
  failure: (type: StateError, frame: .new(.parse('file:///a_test.dart'), 7)),
);

/// A failed outcome of [run], whose shrinking ended on [end] after [steps]
/// steps over [time].
Failed _failed(
  Threw run, {
  ShrinkEnd end = .shrunk,
  int steps = 12,
  Duration time = const .new(milliseconds: 34),
}) => .new(run.record, run, steps: steps, time: time, end: end);

/// The Dart of the default settings filled from seed 7.
const String _settings = 'Settings(seed: 7)';

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

    test('failed reports its smallest case, its shrinking and its seed', () {
      final Threw run = _threw(
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
        'Seed 7. Repeat this search with `settings: Settings(seed: 7)`.',
      );
    });

    test('flaky reports its failure and how its replay ended', () {
      final Threw failed = _threw(draws: [(label: 'x', value: 2, text: '2')]);
      final Run replay = Returned(failed.record, const [], const []);
      expect(
        report(Flaky(failed, replay), seed: 7, settings: _settings),
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

  group('a failed outcome', () {
    test('whose step budget ran out says its case is the smallest found', () {
      expect(
        report(
          _failed(_threw(), end: .steps, steps: 5000),
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
          _failed(_threw(), end: .time, steps: 1, time: .new(seconds: 10)),
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

    test('prints each value\'s text as it was drawn, not the value as the '
        'body left it', () {
      final Threw run = _threw(
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
        report(_failed(_threw()), seed: 7, settings: _settings),
        contains('It drew nothing.'),
      );
    });

    test('indents every line of a value and an error that is not empty '
        'under its heading', () {
      final Threw run = _threw(
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
      final Threw run = _threw(
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
      final Threw run = _threw(
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
    /// A text over letters, spaces and newlines, which a report indents.
    final Gen<String> text = .string(alphabet: .of('a \n'), maxLength: 8);

    property('Whatever a note\'s or a drawn value\'s text holds, the report '
        'prints it under its heading line for line, two spaces opening each '
        'line that is not empty, with its trailing whitespace trimmed and no '
        'line the indent alone.', (Draw draw) {
      final String drawn = draw(text, label: 'drawn');
      final String noted = draw(text, label: 'noted');
      final String printed = report(
        _failed(
          _threw(
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
      for (final (String written, String? part) in [
        (drawn, parts[1]),
        (noted, parts[2]),
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
    final Threw failed = _threw();

    test('rejected says so', () {
      expect(
        report(
          Flaky(failed, Rejected(failed.record, [], [])),
          seed: 7,
          settings: _settings,
        ),
        contains('Run again, it was rejected.'),
      );
    });

    test('overrun says so', () {
      expect(
        report(
          Flaky(failed, Overran(failed.record, [], [])),
          seed: 7,
          settings: _settings,
        ),
        contains('Run again, it made more choices than its case holds.'),
      );
    });

    test('that threw another way names its error and frame', () {
      final Threw other = .new(
        failed.record,
        const [],
        const [],
        error: ArgumentError('odd'),
        stackTrace: .empty,
        failure: (
          type: ArgumentError,
          frame: .new(.parse('file:///a_test.dart'), 9),
        ),
      );
      expect(
        report(Flaky(failed, other), seed: 7, settings: _settings),
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
        failure: (type: StateError, frame: null),
      );
      expect(
        report(Flaky(failed, other), seed: 7, settings: _settings),
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
        failure: (type: ArgumentError, frame: null),
      );
      expect(
        report(Flaky(failed, other), seed: 7, settings: _settings),
        contains('ArgumentError from a stack grit could not read:'),
      );
    });
  });
}
