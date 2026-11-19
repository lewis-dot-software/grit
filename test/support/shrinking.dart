import 'package:grit/src/choice/choice_sequence.dart';
import 'package:grit/src/choice/span.dart';
import 'package:grit/src/shrink/shrink.dart';
import 'package:test/test.dart';

import 'oracle.dart';
import 'spans.dart';

/// One step of a shrinking:
///
/// - `from`: the current sequence.
/// - `candidate`: the candidate it proposed.
/// - `record`: the choices the candidate's run read, where it was told as
///   failing, and null where it was told as not failing.
typedef ShrinkStep = ({
  ChoiceSequence from,
  ChoiceSequence candidate,
  ChoiceSequence? record,
});

/// What a candidate's run told as failing made:
///
/// - `read`: how many of the candidate's choices it read.
/// - `spans`: the span of each draw it made.
typedef Failing = ({int read, List<Span> spans});

/// A shrinking along an oracle's answers:
///
/// - `path`: each step it took, in order.
/// - `end`: the state it ended in.
typedef Answered = ({List<ShrinkStep> path, Shrunk end});

/// The most steps a shrinking along an oracle's answers may take before it
/// is held never to end, far past the longest any drawn oracle's takes.
const int _endless = 1000000;

/// The first [read] choices of [candidate], the record a run on it made
/// having read them.
ChoiceSequence recordOf(ChoiceSequence candidate, int read) =>
    .new(candidate.choices.take(read));

/// The state after [shrink]'s candidate's run, which failed as the first
/// failure did having read [read] of its choices, or did not fail where
/// [read] is null, making the spans [spansOf] gives the choices it read.
Shrink tell(Shrinking shrink, {required int? read}) => switch (read) {
  final int read => shrink.toldFailing(
    read: read,
    spans: spansOf(recordOf(shrink.candidate, read)),
  ),
  null => shrink.toldNotFailing(),
};

/// The state [shrink] ends in, each candidate told as failing where
/// [failing] gives what its run made, and as not failing where it gives
/// null.
Shrunk shrunk(Shrink shrink, Failing? Function(ChoiceSequence) failing) {
  while (true) {
    switch (shrink) {
      case Shrunk():
        return shrink;
      case Shrinking():
        shrink = switch (failing(shrink.candidate)) {
          (:final int read, :final List<Span> spans) => shrink.toldFailing(
            read: read,
            spans: spans,
          ),
          null => shrink.toldNotFailing(),
        };
    }
  }
}

/// The path from shrinking [first] to its end, each candidate told as
/// failing as [oracle] answers it in turn, with the state it ends in, each
/// run making the spans [spansOf] gives the choices it read.
///
/// Fails the test where the path passes [_endless] steps, or where a
/// candidate told as failing leaves the current sequence no smaller, since a
/// path that never ends either refuses without end or accepts without
/// descending.
Answered answered(ChoiceSequence first, Oracle oracle) {
  final List<ShrinkStep> path = [];
  Shrink shrink = .start(first, spansOf(first));
  while (true) {
    switch (shrink) {
      case Shrunk():
        return (path: path, end: shrink);
      case Shrinking(
        :final ChoiceSequence current,
        :final ChoiceSequence candidate,
      ):
        if (path.length >= _endless) fail('$first passed $_endless steps');
        final int? read = answerOf(oracle, path.length, candidate);
        path.add((
          from: current,
          candidate: candidate,
          record: read == null ? null : recordOf(candidate, read),
        ));
        shrink = tell(shrink, read: read);
        if (read != null && !shrink.current.isSmallerThan(current)) {
          fail('$first accepted $candidate without descending from $current');
        }
    }
  }
}
