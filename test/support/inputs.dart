import 'package:grit/grit.dart';
import 'package:grit/src/choice/zigzag.dart';

/// The largest values a drawn choice reaches at each of its scales: a bit, a
/// few values, a byte, a word and the largest a choice holds.
final List<int> _scales = [1, 3, 255, 0xFFFFFFFF, Choice.largest.value];

/// A choice at one of a few scales, so a drawn sequence holds choices equal
/// to one another as well as far apart.
///
/// Its simplest value is 0, at the scale of a bit.
final Gen<Choice> anyChoice = .build((Draw draw) {
  final int scale = draw(.element(_scales));
  return .new(draw(.integer(min: 0, max: scale)));
});

/// A sequence of choices, each at any scale.
final Gen<ChoiceSequence> anySequence = .list(
  anyChoice,
).map(ChoiceSequence.new);

/// A sequence of choices from 0 to 3, runs of them flattened, so it reaches
/// dozens of choices, most of which grit's generators draw from without a
/// stop.
final Gen<ChoiceSequence> smallSequence =
    .list(.list(.integer(min: 0, max: 3).map(Choice.new))).map(
      (List<List<Choice>> runs) =>
          .new([for (final List<Choice> choices in runs) ...choices]),
    );

/// A sequence of small choices, which a generator mostly draws from to its
/// end, or one of choices at any scale, which mostly stops it.
final Gen<ChoiceSequence> smallOrAnySequence = .oneOf([
  smallSequence,
  anySequence,
]);

/// A zigzag at any scale, up to the widest a choice holds.
final Gen<Zigzag> anyZigzag = .build((Draw draw) {
  final int below = draw(anyChoice).value;
  final int above = draw(.integer(min: 0, max: Choice.largest.value - below));
  return .new(below: below, above: above);
});
