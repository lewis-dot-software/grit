part of 'gen.dart';

/// An integer from [min] to [max], one choice zigzagging out from the value
/// in range nearest 0, naming the choice of the end its bound does not stand
/// for as an edge.
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
  final int below = target - min;
  final int above = max - target;
  final Bound bound = .new(max - min);
  final List<Choice> edges = [?_otherEnd(below: below, above: above)];
  return ._(
    (Draw draw) => _zigzag(
      draw._source.choose(bound, edges: edges).value,
      target: target,
      below: below,
      above: above,
    ),
  );
}

/// The choice of the end the bound does not stand for, counting out with
/// [below] values under the target and [above] over it, or null where the
/// range has values on one side of the target alone.
///
/// The bound stands for the end of the longer side, and for the lower end
/// where the two sides are alike.
Choice? _otherEnd({required int below, required int above}) {
  if (below == 0 || above == 0) return null;
  return above > below ? .new(2 * below) : .new(2 * above - 1);
}

/// The value [choice] stands for, counting out from [target] with [below]
/// values under it and [above] over it.
///
/// Choices alternate above and below [target], above first, until one side
/// runs out, then count on along the other, so a larger choice never stands
/// for a value nearer [target].
int _zigzag(
  int choice, {
  required int target,
  required int below,
  required int above,
}) {
  final int paired = below < above ? below : above;
  if (choice > 2 * paired) {
    final int beyond = choice - paired;
    return above > below ? target + beyond : target - beyond;
  }
  final int distance = (choice + 1) >> 1;
  return choice.isOdd ? target + distance : target - distance;
}
