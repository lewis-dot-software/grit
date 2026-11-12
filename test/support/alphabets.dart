import 'package:grit/grit.dart';

/// An alphabet a string is checked over, with what it holds read apart from
/// drawing it.
///
/// - `name`: the alphabet, in words.
/// - `alphabet`: the alphabet itself.
/// - `size`: how many characters it holds.
/// - `simplest`: its simplest character.
/// - `holds`: whether it holds a code point.
typedef Letters = ({
  String name,
  Alphabet alphabet,
  int size,
  String simplest,
  bool Function(int codePoint) holds,
});

/// Whether [codePoint] lies from [first] to [last], each inclusive.
bool _within(int codePoint, int first, int last) =>
    codePoint >= first && codePoint <= last;

/// Each preset alphabet, with what its docs say it holds.
final List<Letters> presets = [
  (
    name: 'lower case',
    alphabet: .lowerCase,
    size: 26,
    simplest: 'a',
    holds: (int c) => _within(c, 0x61, 0x7A),
  ),
  (
    name: 'upper case',
    alphabet: .upperCase,
    size: 26,
    simplest: 'A',
    holds: (int c) => _within(c, 0x41, 0x5A),
  ),
  (
    name: 'letters',
    alphabet: .letters,
    size: 52,
    simplest: 'A',
    holds: (int c) => _within(c, 0x41, 0x5A) || _within(c, 0x61, 0x7A),
  ),
  (
    name: 'digits',
    alphabet: .digits,
    size: 10,
    simplest: '0',
    holds: (int c) => _within(c, 0x30, 0x39),
  ),
  (
    name: 'letters and digits',
    alphabet: .lettersAndDigits,
    size: 62,
    simplest: '0',
    holds: (int c) =>
        _within(c, 0x30, 0x39) ||
        _within(c, 0x41, 0x5A) ||
        _within(c, 0x61, 0x7A),
  ),
  (
    name: 'ASCII',
    alphabet: .ascii,
    size: 128,
    simplest: '0',
    holds: (int c) => _within(c, 0, 0x7F),
  ),
  (
    name: 'Unicode',
    alphabet: .unicode,
    size: 0x110000 - 0x800,
    simplest: '0',
    holds: (int c) => _within(c, 0, 0x10FFFF) && !_within(c, 0xD800, 0xDFFF),
  ),
];

/// The alphabet of [characters]' code points, which holds at least one.
Letters lettersOf(String characters) {
  final Set<int> codePoints = characters.runes.toSet();
  return (
    name: 'the characters of "$characters"',
    alphabet: .of(characters),
    size: codePoints.length,
    simplest: String.fromCharCode(codePoints.first),
    holds: codePoints.contains,
  );
}
