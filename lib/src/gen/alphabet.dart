part of 'gen.dart';

/// The characters a string is drawn over, each a Unicode scalar value, in
/// order from the simplest.
///
/// Its static members are the presets, named by dot shorthand wherever an
/// [Alphabet] is expected, and [Alphabet.of] builds one from a string.
sealed class Alphabet {
  const Alphabet._();

  /// The characters of [characters], simplest first, each kept where it
  /// first appears.
  ///
  /// [characters] holds at least one, and no surrogate standing alone, since
  /// two drawn side by side would join into another character.
  factory Alphabet.of(String characters) = _Listed._;

  /// The lower case letters `a` to `z`.
  static const Alphabet lowerCase = _Runs([(first: 0x61, last: 0x7A)]);

  /// The upper case letters `A` to `Z`.
  static const Alphabet upperCase = _Runs([(first: 0x41, last: 0x5A)]);

  /// The letters, upper case `A` to `Z`, then lower case `a` to `z`.
  static const Alphabet letters = _Runs([
    (first: 0x41, last: 0x5A),
    (first: 0x61, last: 0x7A),
  ]);

  /// The digits `0` to `9`.
  static const Alphabet digits = _Runs([(first: 0x30, last: 0x39)]);

  /// The digits `0` to `9`, then the letters as [letters] orders them.
  static const Alphabet lettersAndDigits = _Runs([
    (first: 0x30, last: 0x39),
    (first: 0x41, last: 0x5A),
    (first: 0x61, last: 0x7A),
  ]);

  /// The 128 ASCII characters, `0` to `Z` first, then those below `0` from
  /// the nearest down, then those above `Z`.
  ///
  /// A shrunk string reads as digits and capitals where it can, rather than
  /// as control characters a report cannot show.
  static const Alphabet ascii = _Runs([
    (first: 0x30, last: 0x5A),
    (first: 0x2F, last: 0x00),
    (first: 0x5B, last: 0x7F),
  ]);

  /// Every Unicode scalar value, which is every code point but the
  /// surrogates, ordered as [ascii] orders the ASCII, then the rest by code
  /// point.
  static const Alphabet unicode = _Runs([
    (first: 0x30, last: 0x5A),
    (first: 0x2F, last: 0x00),
    (first: 0x5B, last: 0xD7FF),
    (first: 0xE000, last: 0x10FFFF),
  ]);

  /// How many characters it holds.
  int get _size;

  /// The code point at [index], counted from the simplest.
  int _codePointAt(int index);
}

/// A run of consecutive code points, counting up where `last` lies above
/// `first` and down where it lies below.
///
/// - `first`: the run's first code point, inclusive.
/// - `last`: the run's last code point, inclusive.
typedef _Run = ({int first, int last});

/// An alphabet of runs of consecutive code points, in order.
final class _Runs extends Alphabet {
  const _Runs(this._runs) : super._();

  final List<_Run> _runs;

  @override
  int get _size => _runs.fold(
    0,
    (int size, _Run run) => size + (run.last - run.first).abs() + 1,
  );

  @override
  int _codePointAt(int index) {
    int rest = index;
    for (final (:int first, :int last) in _runs) {
      final int length = (last - first).abs() + 1;
      if (rest < length) return last >= first ? first + rest : first - rest;
      rest -= length;
    }
    throw RangeError.range(index, 0, _size - 1, 'index');
  }
}

/// An alphabet of a string's characters, in the order the string holds them.
final class _Listed extends Alphabet {
  _Listed._(String characters)
    : _codePoints = .unmodifiable(_parse(characters)),
      super._();

  final List<int> _codePoints;

  @override
  int get _size => _codePoints.length;

  @override
  int _codePointAt(int index) => _codePoints[index];

  /// The code points of [characters], each kept where it first appears.
  static Set<int> _parse(String characters) {
    final Set<int> codePoints = {};
    for (final int rune in characters.runes) {
      if (rune >= 0xD800 && rune <= 0xDFFF) {
        throw ArgumentError.value(
          characters,
          'characters',
          'Holds the lone surrogate U+${rune.toRadixString(16).toUpperCase()}',
        );
      }
      codePoints.add(rune);
    }
    if (codePoints.isEmpty) {
      throw ArgumentError.value(
        characters,
        'characters',
        'Must hold at least one',
      );
    }
    return codePoints;
  }
}
