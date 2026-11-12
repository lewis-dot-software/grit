import 'package:grit/src/choice/choice_sequence.dart';
import 'package:grit/src/shrink/shrink.dart';
import 'package:test/test.dart';

import 'oracle.dart';

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

/// The state [shrink] ends in, told of each candidate whether [fails].
Shrunk shrunk(Shrink shrink, bool Function(ChoiceSequence) fails) {
  while (true) {
    switch (shrink) {
      case Shrunk():
        return shrink;
      case Shrinking():
        shrink = shrink.told(failed: fails(shrink.candidate));
    }
  }
}

/// The path from shrinking [first] to its end, each candidate told as
/// failing as [oracle] answers it in turn, with the state it ends in.
///
/// Fails the test where the path passes [_endless] steps.
(List<ShrinkStep>, Shrunk) answered(ChoiceSequence first, Oracle oracle) {
  final List<ShrinkStep> path = [];
  Shrink shrink = .start(first);
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
        shrink = shrink.told(failed: failed);
    }
  }
}
