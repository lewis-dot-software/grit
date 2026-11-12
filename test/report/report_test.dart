import 'package:grit/src/engine/outcome.dart';
import 'package:grit/src/engine/run.dart';
import 'package:grit/src/engine/shrink_end.dart';
import 'package:grit/src/gen/gen.dart';
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
  stackTrace: StackTrace.empty,
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

void main() {
  group('an outcome', () {
    test('passed reports its run count', () {
      expect(
        report(Passed(runs: 100), seed: 7),
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
        report(_failed(run), seed: 7),
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
        report(Flaky(failed, replay), seed: 7),
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
        report(GaveUp(rejected: 990, overran: 10), seed: 7),
        'The property gave up: 990 runs were rejected and 10 overran before '
        'enough returned. A run is rejected by an assume that is false or a '
        'filter that finds no value, and overruns where it makes more choices '
        'than one run may.\n'
        '\n'
        'Seed 7. Repeat this search with `settings: Settings(seed: 7)`.',
      );
    });
  });

  group('a failed outcome', () {
    test('whose step budget ran out says its case is the smallest found', () {
      expect(
        report(_failed(_threw(), end: .steps, steps: 5000), seed: 7),
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
        ],
      );
      expect(
        report(_failed(run), seed: 7),
        contains('It drew:\n  xs: [0, 1]\n\n'),
      );
    });

    test('that drew nothing says so', () {
      expect(report(_failed(_threw()), seed: 7), contains('It drew nothing.'));
    });

    test('indents every line of a value and an error under its heading', () {
      final Threw run = _threw(
        draws: [(label: 'text', value: 'one\ntwo', text: 'one\ntwo')],
        message: 'first\nsecond\n',
      );
      expect(
        report(_failed(run), seed: 7),
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
  });

  group('a flaky replay', () {
    final Threw failed = _threw();

    test('rejected says so', () {
      expect(
        report(Flaky(failed, Rejected(failed.record, [], [])), seed: 7),
        contains('Run again, it was rejected.'),
      );
    });

    test('overrun says so', () {
      expect(
        report(Flaky(failed, Overran(failed.record, [], [])), seed: 7),
        contains('Run again, it made more choices than its case holds.'),
      );
    });

    test('that threw another way names its error and frame', () {
      final Threw other = .new(
        failed.record,
        const [],
        const [],
        error: ArgumentError('odd'),
        stackTrace: StackTrace.empty,
        failure: (
          type: ArgumentError,
          frame: .new(.parse('file:///a_test.dart'), 9),
        ),
      );
      expect(
        report(Flaky(failed, other), seed: 7),
        contains(
          'Run again, it threw another way, ArgumentError from '
          'file:///a_test.dart:9:\n'
          '  Invalid argument(s): odd\n',
        ),
      );
    });

    test('that threw from no frame grit reads says so', () {
      final Threw other = .new(
        failed.record,
        const [],
        const [],
        error: ArgumentError('odd'),
        stackTrace: StackTrace.empty,
        failure: (type: ArgumentError, frame: null),
      );
      expect(
        report(Flaky(failed, other), seed: 7),
        contains('ArgumentError from a stack grit could not read:'),
      );
    });
  });
}
