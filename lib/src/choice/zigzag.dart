import 'bound.dart';
import 'choice.dart';

/// How the choices under one bound stand for distances from a centre, with
/// [below] distances under it and [above] over it.
///
/// Choices alternate above and below the centre, above first, until one side
/// runs out, then count on along the other, so a larger choice never stands
/// for a distance nearer the centre. A zigzag with nothing below counts each
/// choice as its own distance.
final class Zigzag {
  const Zigzag._(this.below, this.above);

  /// The zigzag with [below] distances under its centre and [above] over it,
  /// neither negative, and no more in all than [Choice.largest].
  factory Zigzag({required int below, required int above}) {
    RangeError.checkNotNegative(below, 'below');
    RangeError.checkNotNegative(above, 'above');
    // Taken as a difference, since `below + above` wraps past the largest
    // int.
    if (above > Choice.largest.value - below) {
      throw RangeError(
        'The sides $below and $above hold more distances than a choice does',
      );
    }
    return ._(below, above);
  }

  /// The zigzag of [bound] with nothing below its centre.
  factory Zigzag.counting(Bound bound) => .new(below: 0, above: bound.value);

  /// How many distances lie under the centre.
  final int below;

  /// How many distances lie over the centre.
  final int above;

  /// The bound every choice of this zigzag lies within.
  Bound get bound => .new(below + above);

  /// The choice of the end [bound] does not stand for, or null where the
  /// zigzag has distances on one side of its centre alone.
  ///
  /// [bound] stands for the end of the longer side, and for the lower end
  /// where the two sides are alike.
  Choice? get otherEnd {
    if (below == 0 || above == 0) return null;
    return above > below ? .new(2 * below) : .new(2 * above - 1);
  }

  /// The distance [choice], within [bound], stands for, negative below the
  /// centre.
  int distance(Choice choice) {
    final int paired = below < above ? below : above;
    if (choice.value > 2 * paired) {
      final int beyond = choice.value - paired;
      return above > below ? beyond : -beyond;
    }
    final int distance = (choice.value + 1) >> 1;
    return choice.value.isOdd ? distance : -distance;
  }

  /// The choice that stands for [distance], from `-below` to [above].
  Choice at(int distance) {
    final int paired = below < above ? below : above;
    final int away = distance.abs();
    if (away > paired) return .new(away + paired);
    return distance > 0 ? .new(2 * distance - 1) : .new(2 * away);
  }

  @override
  bool operator ==(Object other) =>
      other is Zigzag && other.below == below && other.above == above;

  @override
  int get hashCode => Object.hash(below, above);

  @override
  String toString() => 'Zigzag(below: $below, above: $above)';
}
