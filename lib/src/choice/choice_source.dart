import 'dart:math';

import 'bound.dart';
import 'choice.dart';
import 'choice_sequence.dart';
import 'odds.dart';
import 'status.dart';
import 'sweep.dart';
import 'writes.dart';
import 'zigzag.dart';

/// What hands one run its choices, and records each it hands over.
///
/// A choice the source cannot hand over stops the run: it throws, and every
/// choice asked for after throws again, so a body that catches the throw
/// still ends with the status the source stopped it with.
///
/// A write to the source's record that an error such as a stack overflow
/// cut short leaves it half-written, so from then on the record, its length
/// and every choice asked for throw that error.
sealed class ChoiceSource {
  ChoiceSource._();

  /// A source that fills each choice at random from [random], up to [limit]
  /// choices per run.
  ///
  /// Where [sweep] is given, a choice that names edges is filled at the next
  /// one [sweep] gives it, whatever [near] and [edges] are.
  ///
  /// At [near], any other choice asked for along the zigzag of an earlier
  /// choice of the run is filled beside one of those earlier choices, each
  /// alike: at it or at the distance one either side of it, each alike and
  /// kept within the zigzag. A choice asked for under a bound alone is asked
  /// for along the zigzag that counts it. Otherwise, at [edges], it is filled
  /// at 0, at its bound or at an edge it names, each alike, and otherwise
  /// uniformly within its bound. A weighted choice is filled at its own odds
  /// whatever [near] and [edges] are, and no choice is filled beside it.
  factory ChoiceSource.random(
    Random random, {
    required int limit,
    Sweep? sweep,
    Odds near,
    Odds edges,
  }) = _RandomSource._;

  /// A source that hands over [sequence]'s choices in order, and never fills.
  factory ChoiceSource.fixed(ChoiceSequence sequence) = _FixedSource._;

  final List<Choice> _record = [];
  final Writes _writes = .new();
  Status? _stopped;

  /// The choices handed over so far, in order.
  ChoiceSequence get record {
    _writes.throwIfCut();
    return .new(_record);
  }

  /// How many choices have been handed over so far.
  int get length {
    _writes.throwIfCut();
    return _record.length;
  }

  /// A choice from 0 to [bound], naming [edges], each within [bound], as
  /// choices a random fill's edges reach.
  Choice choose(Bound bound, {List<Choice> edges = const []}) {
    for (final Choice edge in edges) {
      if (!bound.admits(edge)) {
        throw ArgumentError.value(edge, 'edges', 'Must lie within $bound');
      }
    }
    return _choose(.counting(bound), edges);
  }

  /// The distance a choice along [zigzag] stands for, the choice naming
  /// [zigzag]'s other end, where it has one, as an edge a random fill's
  /// edges reach.
  int distance(Zigzag zigzag) =>
      zigzag.distance(_choose(zigzag, [?zigzag.otherEnd]));

  /// A choice of 0 or 1 read as false or true, true at [odds] where the
  /// source fills it.
  bool weigh(Odds odds) {
    _throwIfStopped();
    final Choice choice = _fillWeighted(odds);
    _writes(() => _record.add(choice));
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

  Choice _choose(Zigzag zigzag, List<Choice> edges) {
    _throwIfStopped();
    final Choice choice = _fill(zigzag, edges);
    _writes(() => _record.add(choice));
    return choice;
  }

  Choice _fill(Zigzag zigzag, List<Choice> edges);

  Choice _fillWeighted(Odds odds);

  void _throwIfStopped() {
    _writes.throwIfCut();
    if (_stopped case final Status stopped) _stop(stopped);
  }

  /// Stops the run, keeping the status of the first stop.
  Never _stop(Status status) => throw _Stop(_stopped ??= status);
}

/// A source that fills each choice at random, up to a limit on the choices
/// one run may make.
final class _RandomSource extends ChoiceSource {
  _RandomSource._(
    this._random, {
    required int limit,
    this._sweep,
    this._near = .never,
    this._edges = .never,
  }) : _limit = RangeError.checkNotNegative(limit, 'limit'),
       super._();

  final Random _random;
  final int _limit;
  final Sweep? _sweep;
  final Odds _near;
  final Odds _edges;

  /// The choices filled so far, by the zigzag each was asked for along,
  /// kept only where a choice may be filled beside them.
  final Map<Zigzag, List<Choice>> _filledAlong = {};

  /// How many choices the run has made under each bound naming each set of
  /// edges, kept only where [_sweep] fills them.
  final Map<NamedChoice, int> _alike = {};

  /// The width of the widest bound [Random.nextInt] fills in one call.
  static const int _wordBits = 32;

  @override
  Choice _fill(Zigzag zigzag, List<Choice> edges) {
    _overrunAtLimit();
    final Choice choice = _filled(zigzag, edges);
    if (_near != .never) {
      _writes(() => (_filledAlong[zigzag] ??= []).add(choice));
    }
    return choice;
  }

  /// A choice along [zigzag], filled at the swept named edge, beside an
  /// earlier one, at an edge or uniformly.
  Choice _filled(Zigzag zigzag, List<Choice> edges) {
    final Bound bound = zigzag.bound;
    if (_sweep case final Sweep sweep when edges.isNotEmpty) {
      final NamedChoice named = (bound: bound, edges: .new(edges));
      final int alike = _alike[named] ?? 0;
      _writes(() => _alike[named] = alike + 1);
      if (sweep.next(named, alike: alike) case final Choice edge) return edge;
    }
    // Odds of never draw nothing, so a fill without them fills as it would
    // had they no part in it.
    if (_filledAlong[zigzag] case final List<Choice> earlier
        when _random.nextDouble() < _near.value) {
      return _beside(earlier[_random.nextInt(earlier.length)], zigzag);
    }
    if (_edges != .never && _random.nextDouble() < _edges.value) {
      return _edge(_random.nextInt(edges.length + 2), bound, edges);
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

  /// The edge numbered [index] of a choice under [bound] naming [edges].
  static Choice _edge(int index, Bound bound, List<Choice> edges) =>
      switch (index) {
        0 => .new(0),
        1 => .new(bound.value),
        _ => edges[index - 2],
      };

  /// [earlier], or the choice of the distance one either side of its own
  /// along [zigzag], each alike.
  ///
  /// A step past either end of [zigzag] stays at [earlier], so no sum is
  /// taken past the largest distance.
  Choice _beside(Choice earlier, Zigzag zigzag) {
    final int distance = zigzag.distance(earlier);
    return switch (_random.nextInt(3)) {
      0 when distance > -zigzag.below => zigzag.at(distance - 1),
      2 when distance < zigzag.above => zigzag.at(distance + 1),
      _ => earlier,
    };
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
  Choice _fill(Zigzag zigzag, List<Choice> edges) {
    if (_record.length >= _sequence.choices.length) _stop(.overrun);
    final Choice choice = _sequence.choices[_record.length];
    if (!zigzag.bound.admits(choice)) _stop(.rejected);
    return choice;
  }

  @override
  Choice _fillWeighted(Odds odds) => _fill(.counting(.binary), const []);
}

/// The throw that stops a run, carrying the status it stops it with.
final class _Stop implements Exception {
  _Stop(this.status);

  final Status status;

  @override
  String toString() => 'The choice source stopped the run: ${status.name}';
}
