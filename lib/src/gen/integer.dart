part of 'gen.dart';

/// An integer from [min] to [max], one choice zigzagging out from the value
/// in range nearest 0.
Gen<int> _integer({required int min, required int max}) {
  if (min > max) {
    throw ArgumentError('The minimum $min is above the maximum $max');
  }
  final int width = max - min;
  if (width < 0) {
    throw ArgumentError(
      'The range from $min to $max holds more values than a choice does',
    );
  }
  final int target = 0.clamp(min, max);
  final Bound bound = .new(width);
  return ._(
    (Draw draw) => _zigzag(
      draw._source.choose(bound).value,
      target: target,
      below: target - min,
      above: max - target,
    ),
  );
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
