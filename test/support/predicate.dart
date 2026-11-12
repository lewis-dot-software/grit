/// What a filter's predicate holds for.
enum Predicate {
  /// Every value.
  always,

  /// No value.
  never,

  /// A value whose text is of even length.
  evenText,

  /// A value whose text holds no 0.
  noZero;

  /// Whether this predicate holds for [value].
  bool accepts(Object? value) => switch (this) {
    always => true,
    never => false,
    evenText => '$value'.length.isEven,
    noZero => !'$value'.contains('0'),
  };
}
