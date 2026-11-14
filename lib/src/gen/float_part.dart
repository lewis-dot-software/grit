part of 'gen.dart';

/// One part of a float's range, the doubles one choice under [bound]
/// stands for, simplest first.
sealed class _FloatPart {
  /// The largest choice the part's doubles take.
  Bound get bound;

  /// The choices of the part's named edges.
  List<Choice> get edges;

  /// Whether the choice of part names this one as an edge.
  bool get isNamed;

  /// The double [choice] stands for.
  double at(Choice choice);
}

/// One double alone: an infinity or NaN.
final class _Only extends _FloatPart {
  _Only(this._value);

  final double _value;

  @override
  Bound get bound => .zero;

  @override
  List<Choice> get edges => const [];

  @override
  bool get isNamed => true;

  @override
  double at(Choice choice) => _value;
}

/// The finite doubles of one sign whose magnitudes lie in a range: the whole
/// numbers among them first, then the fractions, each by magnitude.
///
/// Doubles of one sign order by magnitude as their bits do, so the whole
/// numbers and the fractions of a range each count on from the first of
/// their kind in it.
final class _Magnitudes extends _FloatPart {
  _Magnitudes._(double low, double high, {required this._negative})
    : _firstWhole = _wholesBelow(low),
      _firstFraction = _fractionsBelow(low),
      _wholes = _wholesUpTo(high) - _wholesBelow(low),
      _fractions = _fractionsUpTo(high) - _fractionsBelow(low) {
    bound = .new(_wholes + _fractions - 1);
    edges = [
      if (isNamed) .new(0),
      for (final double magnitude in _namedMagnitudes)
        if (low <= magnitude && magnitude <= high) _choiceOf(magnitude),
    ];
  }

  /// The finite doubles of one sign, negative where [negative] holds, whose
  /// magnitudes lie from [low] to [high], or null where none does.
  ///
  /// [low] is never above [high], and neither is negative. Where [low] is 0
  /// and [negative] holds, -0.0 lies in the part.
  static _Magnitudes? within({
    required double low,
    required double high,
    required bool negative,
  }) {
    if (low > double.maxFinite) return null;
    return ._(
      low,
      high > double.maxFinite ? .maxFinite : high,
      negative: negative,
    );
  }

  /// The magnitudes each part names where it holds them: the smallest
  /// subnormal and the largest finite double.
  static const List<double> _namedMagnitudes = [.minPositive, .maxFinite];

  final bool _negative;

  /// How many whole numbers lie below the range, the rank of its first.
  final int _firstWhole;

  /// How many fractions lie below the range, the rank of its first.
  final int _firstFraction;

  /// How many whole numbers the range holds.
  final int _wholes;

  /// How many fractions the range holds.
  final int _fractions;

  @override
  late final Bound bound;

  @override
  late final List<Choice> edges;

  @override
  bool get isNamed => _negative && _firstWhole == 0;

  @override
  double at(Choice choice) {
    final int rank = choice.value;
    final double magnitude = rank < _wholes
        ? _wholeAt(_firstWhole + rank)
        : _fractionAt(_firstFraction + rank - _wholes);
    return _negative ? -magnitude : magnitude;
  }

  /// The choice of [magnitude], which lies in the range.
  Choice _choiceOf(double magnitude) => .new(
    _isWhole(magnitude)
        ? _wholesBelow(magnitude) - _firstWhole
        : _wholes + _fractionsBelow(magnitude) - _firstFraction,
  );

  /// 2 to the 53, past which every double is a whole number and some whole
  /// numbers are no double.
  static const double _exact = 9007199254740992;

  /// Whether [magnitude], which is finite, is a whole number.
  static bool _isWhole(double magnitude) =>
      magnitude == magnitude.truncateToDouble();

  /// How many whole numbers lie below [magnitude], which is finite and
  /// never negative.
  ///
  /// Up to [_exact], every whole number is a double, and past it, every
  /// double is a whole number.
  static int _wholesBelow(double magnitude) => magnitude <= _exact
      ? magnitude.ceil()
      : _exact.toInt() + _bitsOf(magnitude) - _bitsOf(_exact);

  /// How many whole numbers lie at or below [magnitude], which is finite
  /// and never negative.
  static int _wholesUpTo(double magnitude) =>
      _wholesBelow(magnitude) + (_isWhole(magnitude) ? 1 : 0);

  /// How many fractions lie at or below [magnitude], which is finite and
  /// never negative.
  static int _fractionsUpTo(double magnitude) =>
      _fractionsBelow(magnitude) + (_isWhole(magnitude) ? 0 : 1);

  /// How many fractions lie below [magnitude], which is finite and never
  /// negative: the doubles below it less the whole numbers.
  static int _fractionsBelow(double magnitude) =>
      _bitsOf(magnitude) - _wholesBelow(magnitude);

  /// The whole number [rank] whole numbers lie below.
  static double _wholeAt(int rank) => rank <= _exact.toInt()
      ? rank.toDouble()
      : _doubleOf(_bitsOf(_exact) + rank - _exact.toInt());

  /// The fraction [rank] fractions lie below.
  ///
  /// Every double below 1 but 0 is a fraction. From 1 on, each binade from
  /// 2 to the `e` to 2 to the `e + 1` holds 2 to the 52 doubles, a whole
  /// number every 2 to the `52 - e` of them, and the fractions between.
  static double _fractionAt(int rank) {
    final int belowOne = _fractionsBelow(1);
    if (rank < belowOne) return _doubleOf(rank + 1);
    int e = 0;
    while (rank >= _fractionsBelow(_powerOfTwo(e + 1))) {
      e++;
    }
    final int within = rank - _fractionsBelow(_powerOfTwo(e));
    final int step = 1 << (52 - e);
    final int offset = within ~/ (step - 1) * step + within % (step - 1) + 1;
    return _doubleOf(_bitsOf(_powerOfTwo(e)) + offset);
  }

  /// 2 to the [e], for [e] from 0 to 52.
  static double _powerOfTwo(int e) => (1 << e).toDouble();

  /// The bits of [magnitude], which is never negative, as an integer, which
  /// orders as the magnitude does.
  static int _bitsOf(double magnitude) =>
      (ByteData(8)..setFloat64(0, magnitude)).getInt64(0);

  /// The double of [bits].
  static double _doubleOf(int bits) =>
      (ByteData(8)..setInt64(0, bits)).getFloat64(0);
}
