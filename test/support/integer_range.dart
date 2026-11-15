import 'package:grit/grit.dart';

/// The largest magnitude a range's ends reach at each of its scales, the
/// widest of which still holds no more values than a choice does.
final List<int> _magnitudes = [3, 255, 0xFFFFFFFF, (1 << 62) - 1];

/// A range of integers:
///
/// - `min`: its minimum.
/// - `max`: its maximum, never below `min`.
typedef IntegerRange = ({int min, int max});

/// A range of integers at one of a few scales, either side of 0 or across
/// it.
final Gen<IntegerRange> integerRange = .build((Draw draw) {
  final int magnitude = draw(.element(_magnitudes));
  final Gen<int> end = .integer(min: -magnitude, max: magnitude);
  final int a = draw(end);
  final int b = draw(end);
  return a <= b ? (min: a, max: b) : (min: b, max: a);
});
