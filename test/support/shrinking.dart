import 'package:grit/src/choice/choice_sequence.dart';
import 'package:grit/src/choice/span.dart';
import 'package:grit/src/shrink/shrink.dart';
import 'package:test/test.dart';

import 'oracle.dart';
import 'spans.dart';

/// One step of a shrinking: the current sequence, the candidate it proposed,
/// and whether the candidate was told as failing.
typedef ShrinkStep = ({
  ChoiceSequence from,
  ChoiceSequence candidate,
  bool failed,
});

/// The most steps a shrinking along an oracle's answers may take before it
/// is held never to end, far past the longest any drawn oracle's takes.
const int _endless = 1000000;

/// The state after [shrink]'s candidate's run, which [failed] as the first
/// failure did or not, making the spans [spansOf] gives it.
Shrink tell(Shrinking shrink, {required bool failed}) => failed
    ? shrink.toldFailing(spansOf(shrink.candidate))
    : shrink.toldNotFailing();

/// The state [shrink] ends in, each candidate told as failing where
/// [failing] gives the spans its run made, and as not failing where it gives
/// null.
Shrunk shrunk(Shrink shrink, List<Span>? Function(ChoiceSequence) failing) {
  while (true) {
    switch (shrink) {
      case Shrunk():
        return shrink;
      case Shrinking():
        shrink = switch (failing(shrink.candidate)) {
          final List<Span> spans => shrink.toldFailing(spans),
          null => shrink.toldNotFailing(),
        };
    }
  }
}

/// The path from shrinking [first] to its end, each candidate told as
/// failing as [oracle] answers it in turn, with the state it ends in, each
/// run making the spans [spansOf] gives it.
///
/// Fails the test where the path passes [_endless] steps.
(List<ShrinkStep>, Shrunk) answered(ChoiceSequence first, Oracle oracle) {
  final List<ShrinkStep> path = [];
  Shrink shrink = .start(first, spansOf(first));
  while (true) {
    switch (shrink) {
      case Shrunk():
        return (path, shrink);
      case Shrinking(
        :final ChoiceSequence current,
        :final ChoiceSequence candidate,
      ):
        if (path.length >= _endless) fail('$first passed $_endless steps');
        final bool failed = answerOf(oracle, path.length, candidate);
        path.add((from: current, candidate: candidate, failed: failed));
        shrink = tell(shrink, failed: failed);
    }
  }
}
