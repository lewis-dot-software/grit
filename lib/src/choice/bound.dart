import 'choice.dart';

/// The largest choice a generator asks for at one point of a run, inclusive.
extension type const Bound._(int value) implements Object {
  /// The bound of [value], which is never negative.
  factory Bound(int value) => ._(RangeError.checkNotNegative(value, 'value'));

  /// The bound of a choice that can only be 0.
  static const Bound zero = ._(0);

  /// The bound of a choice of 0 or 1.
  static const Bound binary = ._(1);

  /// Whether [choice] lies within this bound.
  bool admits(Choice choice) => choice.value <= value;
}
