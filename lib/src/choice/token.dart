import 'choice.dart';
import 'choice_sequence.dart';
import 'decoding.dart';

/// A choice sequence written as one line of text.
///
/// A token opens with its format, [format], then a colon, then each choice
/// in base 36, lower case and with no leading zero, the choices joined by
/// dots. The empty sequence's token is the format and its colon alone.
abstract final class Token {
  /// The format every token this grit writes opens with, and the one format
  /// it reads.
  static const String format = 'grit1';

  /// A token of some format: `grit` and its version's digits, then a colon.
  static final RegExp _anyFormat = .new(r'^(grit\d+):');

  /// A token of [format], whose choices are each one or more base 36 digits.
  static final RegExp _shape = .new('^$format:([0-9a-z]+(\\.[0-9a-z]+)*)?\$');

  static const int _radix = 36;

  /// The token of [sequence].
  static String encode(ChoiceSequence sequence) =>
      '$format:${sequence.choices.map((Choice choice) => choice.value.toRadixString(_radix)).join('.')}';

  /// The sequence [text] is the token of, or why it is none.
  ///
  /// Text that opens with another format's version is [OtherFormat],
  /// whatever follows it. Any other text that is not the token of the
  /// sequence it reads as, such as a choice with a leading zero or one past
  /// the largest, is [NotAToken].
  static Decoding decode(String text) {
    if (_anyFormat.firstMatch(text)?[1] case final String opened
        when opened != format) {
      return OtherFormat(opened);
    }
    final RegExpMatch? match = _shape.firstMatch(text);
    if (match == null) return NotAToken();
    final List<Choice> choices = [];
    for (final String digits in match[1]?.split('.') ?? const <String>[]) {
      // Digits past the largest choice parse to null.
      final int? value = int.tryParse(digits, radix: _radix);
      if (value == null) return NotAToken();
      choices.add(.new(value));
    }
    final ChoiceSequence sequence = .new(choices);
    return encode(sequence) == text ? Decoded(sequence) : NotAToken();
  }
}
