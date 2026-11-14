/// The words a report and its warnings share.
library;

/// Why a run is invalid: what rejects it, and what overruns it.
const String invalidRuns =
    'A run is rejected by an assume that is false, a filter that finds no '
    'value or a set that finds too few distinct elements, and overruns where '
    'it makes more choices than one run may.';

/// [runs] counted in runs.
String runsText(int runs) => runs == 1 ? '1 run' : '$runs runs';

/// [time] in microseconds under a millisecond, in milliseconds under a
/// second, and in seconds to a tenth above.
String timeText(Duration time) => time < const .new(milliseconds: 1)
    ? '${time.inMicroseconds} µs'
    : time < const .new(seconds: 1)
    ? '${time.inMilliseconds} ms'
    : '${(time.inMilliseconds / 1000).toStringAsFixed(1)} s';
