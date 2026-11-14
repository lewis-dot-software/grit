/// The bounds on one shrinking.
final class Budget {
  /// The bounds of at most [steps] candidates run and [time] taken, neither
  /// of which is negative.
  ///
  /// A negative bound is thrown as a [RangeError] naming [stepsName] or
  /// [timeName], the names its caller gave it.
  Budget({
    required int steps,
    required Duration time,
    String stepsName = 'steps',
    String timeName = 'time',
  }) : steps = RangeError.checkNotNegative(steps, stepsName),
       time = time.isNegative
           ? throw RangeError.range(time.inMicroseconds, 0, null, timeName)
           : time;

  /// The most candidates shrinking runs.
  final int steps;

  /// The longest shrinking may take from its start, by the search's clock.
  final Duration time;
}
