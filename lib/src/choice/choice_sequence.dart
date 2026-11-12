import 'choice.dart';

/// The choices one run made, in order: the run's record.
///
/// Sequences are ordered shortlex: one is smaller than another when it is
/// shorter, or the same length and smaller at its first difference.
final class ChoiceSequence implements Comparable<ChoiceSequence> {
  /// The sequence of [choices], in order.
  ChoiceSequence(Iterable<Choice> choices) : choices = .unmodifiable(choices);

  /// The choices, in the order the run made them.
  final List<Choice> choices;

  /// Whether this sequence is shortlex smaller than [other].
  bool isSmallerThan(ChoiceSequence other) => compareTo(other) < 0;

  /// Negative where this sequence is shortlex smaller than [other], positive
  /// where it is larger, and 0 where the two are equal.
  @override
  int compareTo(ChoiceSequence other) {
    if (choices.length != other.choices.length) {
      return choices.length.compareTo(other.choices.length);
    }
    for (int i = 0; i < choices.length; i++) {
      final int order = choices[i].value.compareTo(other.choices[i].value);
      if (order != 0) return order;
    }
    return 0;
  }

  @override
  bool operator ==(Object other) =>
      other is ChoiceSequence && compareTo(other) == 0;

  @override
  int get hashCode => Object.hashAll(choices);

  @override
  String toString() => choices.toString();
}
