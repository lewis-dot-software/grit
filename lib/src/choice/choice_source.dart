import 'dart:math';

import 'bound.dart';
import 'choice.dart';
import 'choice_sequence.dart';
import 'odds.dart';
import 'status.dart';

/// What hands one run its choices, and records each it hands over.
///
/// A choice the source cannot hand over stops the run: it throws, and every
/// choice asked for after throws again, so a body that catches the throw
/// still ends with the status the source stopped it with.
sealed class ChoiceSource {
  ChoiceSource._();

  /// A source that fills each choice at random from [random], up to [limit]
  /// choices a run.
  ///
  /// At [edges], a choice is filled at 0 or at its bound, each alike, and
  /// otherwise uniformly within its bound. A weighted choice is filled at its
  /// own odds whatever [edges] is.
  factory ChoiceSource.random(Random random, {required int limit, Odds edges}) =
      _RandomSource._;

  /// A source that hands over [sequence]'s choices in order, and never fills.
  factory ChoiceSource.fixed(ChoiceSequence sequence) = _FixedSource._;

  final List<Choice> _record = [];
  Status? _stopped;

  /// The choices handed over so far, in order.
  ChoiceSequence get record => .new(_record);

  /// A choice from 0 to [bound].
  Choice choose(Bound bound) {
    _throwIfStopped();
    final Choice choice = _fill(bound);
    _record.add(choice);
    return choice;
  }

  /// A choice of 0 or 1 read as false or true, true at [odds] where the
  /// source fills it.
  bool weigh(Odds odds) {
    _throwIfStopped();
    final Choice choice = _fillWeighted(odds);
    _record.add(choice);
    return choice.value == 1;
  }

  /// Stops the run as rejected, unless the source has stopped it already.
  Never reject() => _stop(.rejected);

  /// The run's status once its body has ended, having thrown where [threw]
  /// holds.
  ///
  /// A run the source stopped ends with the status it stopped it with,
  /// whatever its body did after. Any other ends [Status.failed] where its
  /// body threw, and [Status.returned] where it returned.
  Status status({required bool threw}) =>
      _stopped ?? (threw ? .failed : .returned);

  Choice _fill(Bound bound);

  Choice _fillWeighted(Odds odds);

  void _throwIfStopped() {
    if (_stopped case final Status stopped) _stop(stopped);
  }

  /// Stops the run, keeping the status of the first stop.
  Never _stop(Status status) => throw _Stop(_stopped ??= status);
}

/// A source that fills each choice at random, up to a limit on the choices
/// one run may make.
final class _RandomSource extends ChoiceSource {
  _RandomSource._(this._random, {required int limit, this._edges = .never})
    : _limit = RangeError.checkNotNegative(limit, 'limit'),
      super._();

  final Random _random;
  final int _limit;
  final Odds _edges;

  /// The width of the widest bound [Random.nextInt] fills in one call.
  static const int _wordBits = 32;

  @override
  Choice _fill(Bound bound) {
    _overrunAtLimit();
    // A uniform fill draws nothing for the edges, so it fills as it would
    // with no edges at all.
    if (_edges != .never && _random.nextDouble() < _edges.value) {
      return _random.nextBool() ? .new(0) : .new(bound.value);
    }
    if (bound.value < 1 << _wordBits) {
      return .new(_random.nextInt(bound.value + 1));
    }
    // Two words, cut to the bound's bit length, and drawn again where the
    // result lies above the bound, so each choice is equally likely.
    final int highBits = bound.value.bitLength - _wordBits;
    while (true) {
      final int high = _random.nextInt(1 << highBits);
      final int low = _random.nextInt(1 << _wordBits);
      final Choice choice = .new(high << _wordBits | low);
      if (bound.admits(choice)) return choice;
    }
  }

  @override
  Choice _fillWeighted(Odds odds) {
    _overrunAtLimit();
    return .new(_random.nextDouble() < odds.value ? 1 : 0);
  }

  void _overrunAtLimit() {
    if (_record.length >= _limit) _stop(.overrun);
  }
}

/// A source that hands over a fixed sequence's choices in order, and never
/// fills.
final class _FixedSource extends ChoiceSource {
  _FixedSource._(this._sequence) : super._();

  final ChoiceSequence _sequence;

  @override
  Choice _fill(Bound bound) {
    if (_record.length >= _sequence.choices.length) _stop(.overrun);
    final Choice choice = _sequence.choices[_record.length];
    if (!bound.admits(choice)) _stop(.rejected);
    return choice;
  }

  @override
  Choice _fillWeighted(Odds odds) => _fill(.binary);
}

/// The throw that stops a run, carrying the status it stops it with.
final class _Stop implements Exception {
  _Stop(this.status);

  final Status status;

  @override
  String toString() => 'The choice source stopped the run: ${status.name}';
}
