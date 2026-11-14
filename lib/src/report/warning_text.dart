import '../engine/warning.dart';
import 'words.dart';

/// The line that warns of [warning].
String warningText(Warning warning) => switch (warning) {
  SlowProperty(:final Duration perRun, :final int runs) =>
    'Warning: the property is slow. Its runs took ${timeText(perRun)} each on '
        'average, so a search of ${runsText(runs)} takes about '
        '${timeText(perRun * runs)}. A lower `runs` setting makes it faster.',
  MostlyInvalid(:final int returned, :final int rejected, :final int overran) =>
    'Warning: most of the property\'s runs were invalid, $rejected rejected '
        'and $overran overrun against $returned returned. $invalidRuns',
};
