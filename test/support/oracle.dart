import 'package:grit/grit.dart';

/// An oracle drawn for the checks on grit:
///
/// - `answers`: whether each candidate fails, in turn, from the first again
///   once they run out, [_cycles] times through, after which none fails.
/// - `unread`: how many choices off its end each failing candidate's run
///   leaves unread, in turn, from the first again once they run out, and
///   none where it is empty.
/// - `shortest`: the length below which no candidate fails.
///
/// An oracle that refuses deletions leaves the passes after them a long
/// sequence to work on, where one that accepts them shrinks it to a few
/// choices before they run.
typedef Oracle = ({List<bool> answers, List<int> unread, int shortest});

/// How many times through its answers an oracle goes before it fails no
/// candidate, so it fails finitely many of those it is asked in turn,
/// however it answers.
const int _cycles = 1000;

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
  unread: draw(.list(.integer(min: 0, max: 3)), label: 'unread'),
  shortest: draw(
    .build(
      (Draw draw) => draw(.boolean())
          ? first.choices.length
          : draw(.integer(min: 0, max: first.choices.length)),
    ),
    label: 'shortest',
  ),
);

/// The [k]th answer of [oracle], to [candidate]: how many of its choices its
/// run read where it fails, and null where it does not.
int? answerOf(Oracle oracle, int k, ChoiceSequence candidate) {
  final int length = candidate.choices.length;
  if (length < oracle.shortest ||
      k >= _cycles * oracle.answers.length ||
      !oracle.answers[k % oracle.answers.length]) {
    return null;
  }
  if (oracle.unread.isEmpty) return length;
  final int unread = oracle.unread[k % oracle.unread.length];
  return unread < length ? length - unread : 0;
}
