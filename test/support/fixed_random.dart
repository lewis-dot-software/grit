import 'dart:math';

/// A [Random] whose every [nextDouble] is one fixed draw.
final class FixedRandom implements Random {
  /// The random whose every [nextDouble] is [draw].
  FixedRandom(this.draw);

  /// The draw every [nextDouble] gives.
  final double draw;

  @override
  double nextDouble() => draw;

  @override
  bool nextBool() => throw UnsupportedError('FixedRandom draws doubles alone');

  @override
  int nextInt(int max) =>
      throw UnsupportedError('FixedRandom draws doubles alone');
}
