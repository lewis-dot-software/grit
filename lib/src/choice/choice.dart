/// One random choice a run made: a natural number from 0 to the bound it was
/// asked under, where 0 is the simplest.
extension type const Choice._(int value) implements Object {
  /// The choice of [value], which is never negative.
  factory Choice(int value) => ._(RangeError.checkNotNegative(value, 'value'));

  /// The largest choice the Dart VM's integers hold.
  static const Choice largest = ._(0x7FFFFFFFFFFFFFFF);
}
