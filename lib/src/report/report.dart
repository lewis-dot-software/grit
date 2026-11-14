import '../engine/outcome.dart';
import '../engine/run.dart';
import '../engine/shrink_end.dart';
import '../gen/gen.dart';

/// The message [outcome] reports, for a search whose random choices were
/// filled from [seed] under the settings the Dart [settings] builds.
///
/// A failed outcome reports its smallest failing case: what the body drew,
/// what it noted and what it threw, and how shrinking ended, saying where the
/// budget ran out that the case is the smallest found within it. Every
/// outcome ends on the seed and the settings, so the search can be repeated.
String report(Outcome outcome, {required int seed, required String settings}) {
  final String body = switch (outcome) {
    Passed(:final int runs) => 'The property passed ${_runs(runs)}.',
    Failed(
      :final Threw run,
      :final ShrinkEnd end,
      :final int steps,
      :final Duration time,
    ) =>
      [_shrinking(end, steps: steps, time: time), _case(run)].join('\n\n'),
    Flaky(:final Threw failed, :final Run replay) => [
      'The property is flaky: it failed, then did not fail the same way when '
          'its failing case ran again.',
      _case(failed),
      'Run again, ${_replayed(replay)}',
    ].join('\n\n'),
    GaveUp(:final int rejected, :final int overran) =>
      'The property gave up: ${_rejected(rejected)} and $overran overran '
          'before enough returned. A run is rejected by an assume that is '
          'false, a filter that finds no value or a set that finds too few '
          'distinct elements, and overruns where it makes more choices than '
          'one run may.',
  };
  return '$body\n\nSeed $seed. Repeat this search with '
      '`settings: $settings`.';
}

/// The line saying how a shrinking of [steps] steps over [time] ended.
String _shrinking(
  ShrinkEnd end, {
  required int steps,
  required Duration time,
}) => switch (end) {
  .shrunk =>
    'The property failed. Its smallest failing case, shrunk in '
        '${_steps(steps)} over ${_time(time)}:',
  .steps =>
    'The property failed. Shrinking ran out of steps after '
        '${_steps(steps)}, over ${_time(time)}, so its failing case is the '
        'smallest found within the budget:',
  .time =>
    'The property failed. Shrinking ran out of time after ${_time(time)}, '
        'in ${_steps(steps)}, so its failing case is the smallest found '
        'within the budget:',
};

/// What [run] drew, noted and threw, one part per paragraph.
String _case(Threw run) => [
  if (run.draws.isEmpty)
    'It drew nothing.'
  else
    'It drew:\n${run.draws.map(_drawn).join('\n')}',
  if (run.notes.isNotEmpty) 'It noted:\n${run.notes.map(_indented).join('\n')}',
  'It threw:\n${_indented('${run.error}')}',
].join('\n\n');

/// One value's text as it was drawn, under its label where it has one.
String _drawn(Drawn drawn) => _indented(switch (drawn) {
  (label: final String label, :final String text, value: _) => '$label: $text',
  (label: null, :final String text, value: _) => text,
});

/// What a replay that did not fail as the first run did ended as.
String _replayed(Run replay) => switch (replay) {
  Returned() => 'it returned.',
  Rejected() => 'it was rejected.',
  Overran() => 'it made more choices than its case holds.',
  Threw(:final Object error) =>
    'it threw another way, ${error.runtimeType} from '
        '${replay.failure.frame ?? 'a stack grit could not read'}:\n'
        '${_indented('$error')}',
};

/// [text] indented under its heading, its trailing whitespace trimmed and
/// each empty line left empty, so no line is spaces the text did not hold.
String _indented(String text) => text
    .trimRight()
    .split('\n')
    .map((String line) => line.isEmpty ? line : '  $line')
    .join('\n');

String _steps(int steps) => steps == 1 ? '1 step' : '$steps steps';

String _runs(int runs) => runs == 1 ? '1 run' : '$runs runs';

String _rejected(int rejected) =>
    rejected == 1 ? '1 run was rejected' : '$rejected runs were rejected';

/// [time] in milliseconds under a second, and in seconds to a tenth above.
String _time(Duration time) => time < const .new(seconds: 1)
    ? '${time.inMilliseconds} ms'
    : '${(time.inMilliseconds / 1000).toStringAsFixed(1)} s';
