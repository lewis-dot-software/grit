/// How likely a weighted choice is to be filled as 1, from 0 to 1.
extension type const Odds._(double value) implements Object {
  /// The odds of [value], which lies from 0 to 1.
  factory Odds(double value) {
    if (!(value >= 0 && value <= 1)) {
      throw RangeError.value(value, 'value', 'Must be from 0 to 1');
    }
    return ._(value);
  }
}
