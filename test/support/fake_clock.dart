import 'package:grit/src/engine/clock.dart';

/// A clock that moves only as its ticks say: each read gives the time
/// elapsed so far, then moves on by the next tick, the ticks taken in turn.
///
/// A clock of no ticks never moves.
final class FakeClock implements Clock {
  /// The clock that moves by [ticks] in turn, one a read.
  FakeClock([this._ticks = const []]);

  final List<Duration> _ticks;
  Duration _elapsed = .zero;
  int _reads = 0;

  @override
  Duration get elapsed {
    final Duration read = _elapsed;
    if (_ticks.isNotEmpty) _elapsed += _ticks[_reads++ % _ticks.length];
    return read;
  }
}
