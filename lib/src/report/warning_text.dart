import '../choice/decoding.dart';
import '../engine/warning.dart';
import 'undecodable_text.dart';
import 'words.dart';

/// The line that warns of [warning].
String warningText(Warning warning) => switch (warning) {
  SlowProperty(:final Duration perRun, :final int runs) =>
    'Warning: the property is slow. Its runs took ${timeText(perRun)} each on '
        'average, so a search of ${counted(runs, 'run')} takes about '
        '${timeText(perRun * runs)}. A lower `runs` setting makes it faster, '
        'and an `expectedRunTime` setting declares runs this slow expected.',
  MostlyInvalid(:final int returned, :final int rejected, :final int overran) =>
    'Warning: most of the property\'s runs were invalid, $rejected rejected '
        'and $overran overrun against $returned returned. $invalidRuns',
  UnreadableStored(:final Undecodable reason) =>
    'Warning: the failure stored for this call site '
        '${undecodableText(reason)}, so the search deleted it and generated '
        'its runs afresh.',
};
