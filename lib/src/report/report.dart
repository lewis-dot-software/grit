import '../choice/choice_sequence.dart';
import '../choice/token.dart';
import '../engine/first_found.dart';
import '../engine/outcome.dart';
import '../engine/run.dart';
import '../engine/shrink_end.dart';
import '../gen/gen.dart';
import 'warning_text.dart';
import 'words.dart';

/// The message [outcome] reports, for a search whose random choices were
/// filled from [seed] under the settings the Dart [settings] builds.
///
/// A failed outcome reports its smallest failing case: what the body drew,
/// what it noted and what it threw, how shrinking ended, saying where the
/// budget ran out that the case is the smallest found within it, and the
/// token that replays the case alone. A failure first found from the store
/// says so. Each of the outcome's warnings follows, one per paragraph. The
/// outcome of a search ends on the seed and the settings, so the search can
/// be repeated, a failed one saying that the store's replay of its failure
/// comes first, and the outcome of a token's replay on how to search
/// again.
String report(Outcome outcome, {required int seed, required String settings}) {
  final String repeat =
      'Seed $seed. Repeat this search with `settings: $settings`.';
  final (List<String> body, List<String> end) = switch (outcome) {
    Passed(:final int runs) => (
      ['The property passed ${runsText(runs)}.'],
      [repeat],
    ),
    Failed(
      :final ChoiceSequence sequence,
      :final Threw run,
      :final FirstFound firstFound,
      :final ShrinkEnd end,
      :final int steps,
      :final Duration time,
    ) =>
      (
        [
          _shrinking(end, steps: steps, time: time),
          _case(run),
          ?_found(firstFound),
        ],
        [
          'Replay this case alone with '
              '`settings: Settings(replay: \'${Token.encode(sequence)}\')`.',
          'Seed $seed. The next search at this call site replays this failure '
              'first, so `settings: $settings` repeats this search once '
              '`.dart_tool/grit/` no longer holds it.',
        ],
      ),
    Flaky(
      :final Threw failed,
      :final FirstFound firstFound,
      :final Run replay,
    ) =>
      (
        [
          'The property is flaky: it failed, then did not fail the same way '
              'when its failing case ran again.',
          _case(failed),
          ?_found(firstFound),
          'Run again, ${_replayed(replay)}',
        ],
        [repeat],
      ),
    GaveUp(:final int rejected, :final int overran) => (
      [
        'The property gave up: ${_rejected(rejected)} and $overran overran '
            'before enough returned. $invalidRuns',
      ],
      [repeat],
    ),
    Reproduced(:final Threw run) => (
      [
        'The property failed on the case its replay token names, run once '
            'with no shrinking:',
        _case(run),
      ],
      [_searchAgain],
    ),
    NotReproduced(:final Run run) => (
      [
        'The replay token no longer reproduces a failure: run once, '
            '${_replayed(run)}',
      ],
      [_searchAgain],
    ),
  };
  return [...body, ...outcome.warnings.map(warningText), ...end].join('\n\n');
}

/// The line that ends a token replay's report.
const String _searchAgain =
    'Remove `replay` from the settings to search for a failure again.';

/// The line saying a failure was first found from the store, or null where
/// generation found it.
String? _found(FirstFound firstFound) => switch (firstFound) {
  .generated => null,
  .stored =>
    'It was first found by replaying the failure an earlier search stored '
        'for this call site.',
};

/// The line saying how a shrinking of [steps] steps over [time] ended.
String _shrinking(
  ShrinkEnd end, {
  required int steps,
  required Duration time,
}) => switch (end) {
  .shrunk =>
    'The property failed. Its smallest failing case, shrunk in '
        '${_steps(steps)} over ${timeText(time)}:',
  .steps =>
    'The property failed. Shrinking ran out of steps after '
        '${_steps(steps)}, over ${timeText(time)}, so its failing case is the '
        'smallest found within the budget:',
  .time =>
    'The property failed. Shrinking ran out of time after ${timeText(time)}, '
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

String _rejected(int rejected) =>
    rejected == 1 ? '1 run was rejected' : '$rejected runs were rejected';
