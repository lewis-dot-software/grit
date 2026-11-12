/// A monotonic clock: the time elapsed since some fixed start, which never
/// goes back.
abstract interface class Clock {
  /// The time elapsed since the clock's start.
  Duration get elapsed;
}
