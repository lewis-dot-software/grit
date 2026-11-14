import 'settings.dart';

/// A unit [Duration] is built in: its [name] as a constructor's parameter,
/// and how many [micros] one of it holds.
typedef _Unit = ({String name, int micros});

/// The Dart that builds a search's settings, for its report to repeat it by.
extension SettingsSource on Settings {
  /// The Dart that builds these settings filled from [seed], naming each
  /// other setting a search reads that is not its default.
  String source({required int seed}) {
    final Settings defaults = .new();
    final List<String> named = [
      'seed: $seed',
      if (runs != defaults.runs) 'runs: $runs',
      if (shrinkSteps != defaults.shrinkSteps) 'shrinkSteps: $shrinkSteps',
      if (shrinkTime != defaults.shrinkTime)
        'shrinkTime: ${_duration(shrinkTime)}',
    ];
    return 'Settings(${named.join(', ')})';
  }

  /// The Dart that builds [time], in the largest unit that holds it whole.
  static String _duration(Duration time) {
    final int micros = time.inMicroseconds;
    final _Unit unit = _units.firstWhere(
      (_Unit unit) => micros % unit.micros == 0,
    );
    return 'Duration(${unit.name}: ${micros ~/ unit.micros})';
  }

  /// Each unit [Duration] is built in, largest first.
  static const List<_Unit> _units = [
    (name: 'days', micros: Duration.microsecondsPerDay),
    (name: 'hours', micros: Duration.microsecondsPerHour),
    (name: 'minutes', micros: Duration.microsecondsPerMinute),
    (name: 'seconds', micros: Duration.microsecondsPerSecond),
    (name: 'milliseconds', micros: Duration.microsecondsPerMillisecond),
    (name: 'microseconds', micros: 1),
  ];
}
