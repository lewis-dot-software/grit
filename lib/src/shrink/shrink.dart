import '../choice/choice_sequence.dart';
import '../choice/span.dart';
import 'pass.dart';

/// One state of shrinking a failing sequence: a step function over the
/// current sequence, which is always the first failure or the record a
/// candidate's run read when told as failing, and the spans its run made.
///
/// A round takes every [Pass] in order, each proposing its candidates of the
/// current sequence, and a [Pass.costly] one only where the round has
/// accepted nothing yet. A candidate no smaller than the current sequence is
/// never proposed. Where a candidate is told as failing, the choices its run
/// read become the current sequence, and its pass goes on from the same place
/// among the new sequence's candidates. Shrinking ends on a round that
/// accepts nothing.
sealed class Shrink {
  Shrink._(this.current);

  /// The first state of shrinking [firstFailure], a sequence whose run failed
  /// making [spans].
  factory Shrink.start(ChoiceSequence firstFailure, List<Span> spans) => _seek(
    current: firstFailure,
    spans: spans,
    pass: .values.first,
    at: .first(Pass.values.first.candidates(firstFailure, spans).iterator),
    accepted: false,
  );

  /// The record of the latest run told as failing, the smallest so far, or
  /// the first failure where none has been.
  final ChoiceSequence current;
}

/// A state that proposes a candidate and waits to be told whether its run
/// failed as the first failure did.
final class Shrinking extends Shrink {
  Shrinking._(
    super.current, {
    required this._spans,
    required this._pass,
    required this._at,
    required this._accepted,
  }) : super._();

  /// The spans [current]'s run made.
  final List<Span> _spans;
  final Pass _pass;
  final _Candidate _at;

  /// Whether this round has accepted a candidate yet.
  final bool _accepted;

  /// The sequence to run next, always shortlex smaller than [current].
  ChoiceSequence get candidate => _at.sequence;

  /// The state after [candidate]'s run failed as the first failure did,
  /// having read the first [read] of its choices and made [spans].
  ///
  /// Throws a [RangeError] where [read] is negative or passes the
  /// candidate's length.
  Shrink toldFailing({required int read, required List<Span> spans}) {
    final ChoiceSequence record = .new(
      candidate.choices.take(
        RangeError.checkValueInInterval(
          read,
          0,
          candidate.choices.length,
          'read',
        ),
      ),
    );
    return _seek(
      current: record,
      spans: spans,
      pass: _pass,
      at: .first(
        _pass.candidates(record, spans, from: _at.position).iterator,
        position: _at.position,
      ),
      accepted: true,
    );
  }

  /// The state after [candidate]'s run did not fail as the first failure
  /// did.
  Shrink toldNotFailing() => _seek(
    current: current,
    spans: _spans,
    pass: _pass,
    at: _at.next,
    accepted: _accepted,
  );
}

/// The state shrinking ends in: a round of every pass accepted nothing from
/// [current].
final class Shrunk extends Shrink {
  Shrunk._(super.current) : super._();
}

/// The first state from [at] on that proposes a candidate smaller than
/// [current], whose run made [spans], moving through the passes and into a
/// new round as each runs out, or [Shrunk] where a round ends with nothing
/// [accepted].
Shrink _seek({
  required ChoiceSequence current,
  required List<Span> spans,
  required Pass pass,
  required _Candidate? at,
  required bool accepted,
}) {
  while (true) {
    while (at != null && !at.sequence.isSmallerThan(current)) {
      at = at.next;
    }
    if (at != null) {
      return Shrinking._(
        current,
        spans: spans,
        pass: pass,
        at: at,
        accepted: accepted,
      );
    }
    final Pass? next = .values
        .skip(pass.index + 1)
        .where((Pass later) => !accepted || !later.costly)
        .firstOrNull;
    if (next != null) {
      pass = next;
    } else if (accepted) {
      pass = .values.first;
      accepted = false;
    } else {
      return Shrunk._(current);
    }
    at = .first(pass.candidates(current, spans).iterator);
  }
}

/// One candidate of a pass, at its place among the pass's candidates, with
/// the rest read from the pass only when first asked for.
///
/// Each candidate reads the one after it once, so states that share a
/// candidate share the rest of the pass, and a state is never changed by
/// another's step.
final class _Candidate {
  _Candidate._(this.sequence, this.position, this._rest);

  /// The candidate [rest] reads next, at [position], or null where [rest] has
  /// run out.
  static _Candidate? first(Iterator<ChoiceSequence> rest, {int position = 0}) =>
      rest.moveNext() ? ._(rest.current, position, rest) : null;

  /// The candidate itself.
  final ChoiceSequence sequence;

  /// How many candidates its pass proposes before it.
  final int position;

  final Iterator<ChoiceSequence> _rest;

  /// The candidate after this one, or null where the pass has run out.
  late final _Candidate? next = first(_rest, position: position + 1);
}
