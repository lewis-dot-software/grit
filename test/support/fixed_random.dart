import 'dart:math';

/// A [Random] whose every [nextDouble] is one fixed draw, and whose
/// [nextInt]s are fixed integers in turn.
final class FixedRandom implements Random {
  /// The random whose every [nextDouble] is [draw], and whose [nextInt]s are
  /// [ints] in turn, each below the maximum it is asked for.
  FixedRandom(this.draw, {this._ints = const []});

  /// The draw every [nextDouble] gives.
  final double draw;

  final List<int> _ints;
  int _drawn = 0;

  @override
  double nextDouble() => draw;

  @override
  bool nextBool() => throw UnsupportedError('FixedRandom draws no booleans');

  @override
  int nextInt(int max) {
    if (_drawn >= _ints.length) {
      throw StateError('FixedRandom has drawn all ${_ints.length} integers');
    }
    final int next = _ints[_drawn++];
    if (next >= max) throw RangeError.range(next, 0, max - 1, 'next');
    return next;
  }
}
