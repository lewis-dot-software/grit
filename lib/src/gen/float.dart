part of 'gen.dart';

/// A double from [min] to [max], two choices: the part of the range it lies
/// in, then its place in that part.
///
/// The parts are the finite doubles of positive sign, those of negative
/// sign, positive infinity, negative infinity and NaN, in that order, each
/// where the range and the flags allow it. An infinity or NaN still reads a
/// second choice, which can only be 0, so every value reads two choices and
/// shortlex orders them by part first. Where [nan] is null, NaN is allowed
/// where the range runs from negative infinity to positive infinity.
///
/// The choice of part names -0.0's part, where -0.0 lies in range, and
/// each infinity's and NaN's as edges.
Gen<double> _float({
  required double min,
  required double max,
  required bool? nan,
  required bool infinite,
}) {
  if (min.isNaN || max.isNaN) {
    throw ArgumentError('A bound of NaN orders against no float');
  }
  if (min.compareTo(max) > 0) {
    throw ArgumentError('The minimum $min is above the maximum $max');
  }
  final bool allowsNan = nan ?? (min == .negativeInfinity && max == .infinity);
  final List<_FloatPart> parts = [
    if (!max.isNegative)
      ?_Magnitudes.within(
        low: min.isNegative ? 0 : min,
        high: max,
        negative: false,
      ),
    if (min.isNegative)
      ?_Magnitudes.within(
        low: max.isNegative ? -max : 0,
        high: -min,
        negative: true,
      ),
    if (infinite && max == .infinity) _Only(.infinity),
    if (infinite && min == .negativeInfinity) _Only(.negativeInfinity),
    if (allowsNan) _Only(.nan),
  ];
  if (parts.isEmpty) {
    throw ArgumentError(
      'No float lies from $min to $max where infinities are '
      '${infinite ? 'allowed' : 'not'} and NaN is not',
    );
  }
  final Bound bound = .new(parts.length - 1);
  final List<Choice> edges = [
    for (final (int i, _FloatPart part) in parts.indexed)
      if (part.isNamed) .new(i),
  ];
  return ._((Draw draw) {
    final _FloatPart part =
        parts[draw._source.choose(bound, edges: edges).value];
    return part.at(draw._source.choose(part.bound, edges: part.edges).value);
  });
}
