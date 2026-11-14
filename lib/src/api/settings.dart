import 'package:meta/meta.dart';

import '../choice/choice_sequence.dart';
import '../choice/decoding.dart';
import '../choice/token.dart';
import '../engine/budget.dart';
import '../report/undecodable_text.dart';

/// How one property is searched, each setting with a default no property has
/// to change.
final class Settings {
  /// The settings of a search, each defaulted where it is not given.
  ///
  /// [runs] is at least 1, and [shrinkSteps] and [shrinkTime] never
  /// negative. A [replay] that is no token this grit reads throws an
  /// [ArgumentError] saying whether it is no token or one of another format.
  Settings({
    int runs = 100,
    this.seed,
    int shrinkSteps = 5000,
    Duration shrinkTime = const .new(seconds: 10),
    this.replay,
  }) : runs = runs >= 1 ? runs : throw RangeError.range(runs, 1, null, 'runs'),
       budget = .new(
         steps: shrinkSteps,
         time: shrinkTime,
         stepsName: 'shrinkSteps',
         timeName: 'shrinkTime',
       ),
       replayed = replay == null ? null : _decoded(replay);

  /// How many runs must return for the property to pass.
  final int runs;

  /// The seed the search's random choices are filled from, or null for a
  /// seed drawn afresh each search.
  ///
  /// One seed under the same other settings repeats one search, shrinking
  /// aside where its time runs out, where the store holds no failure for its
  /// call site.
  final int? seed;

  /// The bounds on shrinking, of [shrinkSteps] and [shrinkTime].
  @internal
  final Budget budget;

  /// A failing case's token, which the property replays alone, or null to
  /// search.
  ///
  /// A replay runs the body once on the token's case, with no generation, no
  /// shrinking and no stored failure read or written, and fails where the
  /// case no longer fails, so no token stands in for the search.
  final String? replay;

  /// The sequence [replay] is the token of, or null where it is null.
  @internal
  final ChoiceSequence? replayed;

  /// The most candidates shrinking runs before it ends on the smallest
  /// failure found so far.
  int get shrinkSteps => budget.steps;

  /// The longest shrinking may take before it ends on the smallest failure
  /// found so far.
  ///
  /// The time bounds shrinking alone, so a property passes or fails alike
  /// however long its runs take.
  Duration get shrinkTime => budget.time;

  /// The sequence [token] is the token of, thrown as an [ArgumentError]
  /// where it is none.
  static ChoiceSequence _decoded(String token) => switch (Token.decode(token)) {
    Decoded(:final ChoiceSequence sequence) => sequence,
    final Undecodable reason => throw ArgumentError.value(
      token,
      'replay',
      undecodableText(reason),
    ),
  };
}
