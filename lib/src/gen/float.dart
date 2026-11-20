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
///
/// A fraction names as its simpler form the whole number of its sign whose
/// magnitude is its own rounded up, and an infinity the largest finite whole
/// number of its sign, each where it lies in range, since a binary search
/// over a value's choices passes over a simpler value of larger magnitude.
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
  final _Magnitudes? positive = max.isNegative
      ? null
      : .within(low: min.isNegative ? 0 : min, high: max, negative: false);
  final _Magnitudes? negative = min.isNegative
      ? .within(low: max.isNegative ? -max : 0, high: -min, negative: true)
      : null;
  final List<_FloatPart> parts = [
    ?positive,
    ?negative,
    if (infinite && max == .infinity)
      _Only(.infinity, form: _largestWhole(positive, at: 0)),
    if (infinite && min == .negativeInfinity)
      _Only(
        .negativeInfinity,
        form: _largestWhole(negative, at: positive == null ? 0 : 1),
      ),
    if (allowsNan) _Only(.nan, form: null),
  ];
  if (parts.isEmpty) {
    throw ArgumentError(
      'No float lies from $min to $max where neither an infinity nor NaN is '
      'allowed',
    );
  }
  final Bound bound = .new(parts.length - 1);
  final List<Choice> edges = [
    for (final (int i, _FloatPart part) in parts.indexed)
      if (part.isNamed) .new(i),
  ];
  return ._((Draw draw) {
    final Choice partChoice = draw._source.choose(bound, edges: edges);
    final _FloatPart part = parts[partChoice.value];
    final Choice choice = draw._source.choose(part.bound, edges: part.edges);
    if (part.form(partChoice, choice) case final ChoiceSequence form) {
      draw._name(form);
    }
    return part.at(choice);
  });
}

/// The choices of the largest whole number [part] holds, where [part] is the
/// part at [at] among a float's parts, or null where there is no [part] or
/// it holds no whole number.
ChoiceSequence? _largestWhole(_Magnitudes? part, {required int at}) =>
    switch (part?.largestWhole) {
      final Choice whole => .new([.new(at), whole]),
      null => null,
    };
