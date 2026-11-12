import 'package:grit/grit.dart';

/// An oracle drawn for the checks on grit, which answers as `answers` say
/// in turn, from the first again once they run out, and never fails a
/// candidate shorter than `shortest`.
///
/// An oracle that refuses deletions leaves the passes after them a long
/// sequence to work on, where one that accepts them shrinks it to a few
/// choices before they run.
typedef Oracle = ({List<bool> answers, int shortest});

/// Answers each true at odds from 1 in 2 to 1 in 8, so some oracles accept
/// seldom enough for the passes after zeroing to see choices other than 0.
final Gen<List<bool>> _anyAnswers = .build((Draw draw) {
  final int falses = draw(.integer(min: 1, max: 7));
  return draw(.list(.integer(min: 0, max: falses).map((int i) => i == falses)));
});

/// An oracle for shrinking [first], drawn through [draw], which refuses
/// every deletion or a candidate shorter than a length drawn.
Oracle drawOracle(Draw draw, ChoiceSequence first) => (
  answers: draw(_anyAnswers, label: 'answers'),
  shortest: draw(
    .build(
      (Draw draw) => draw(.boolean())
          ? first.choices.length
          : draw(.integer(min: 0, max: first.choices.length)),
    ),
    label: 'shortest',
  ),
);

/// The [k]th answer of [oracle], to [candidate].
bool answerOf(Oracle oracle, int k, ChoiceSequence candidate) =>
    candidate.choices.length >= oracle.shortest &&
    oracle.answers.isNotEmpty &&
    oracle.answers[k % oracle.answers.length];
