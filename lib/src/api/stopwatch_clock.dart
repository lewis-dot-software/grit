import '../engine/clock.dart';

/// The clock of a [Stopwatch] started as the clock is made.
final class StopwatchClock implements Clock {
  /// The clock started now.
  StopwatchClock() : _stopwatch = Stopwatch()..start();

  final Stopwatch _stopwatch;

  @override
  Duration get elapsed => _stopwatch.elapsed;
}
