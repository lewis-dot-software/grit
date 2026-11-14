part of 'gen.dart';

/// An integer from [min] to [max], one choice zigzagging out from the value
/// in range nearest 0.
Gen<int> _integer({required int min, required int max}) {
  if (min > max) {
    throw ArgumentError('The minimum $min is above the maximum $max');
  }
  // The range's width is taken exactly, since `max - min` wraps past the
  // largest int.
  if (BigInt.from(max) - .from(min) > .from(Choice.largest.value)) {
    throw ArgumentError(
      'The range from $min to $max holds more values than a choice does',
    );
  }
  final int target = 0.clamp(min, max);
  final Zigzag zigzag = .new(below: target - min, above: max - target);
  return ._((Draw draw) => target + draw._source.distance(zigzag));
}
