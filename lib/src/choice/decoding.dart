import 'choice_sequence.dart';
import 'token.dart';

/// What a token's text decodes to.
sealed class Decoding {
  Decoding._();
}

/// Text that is the token of [sequence].
final class Decoded extends Decoding {
  /// The decoding of the token of [sequence].
  Decoded(this.sequence) : super._();

  /// The sequence the text is the token of.
  final ChoiceSequence sequence;
}

/// Text that decodes to no sequence, by why.
sealed class Undecodable extends Decoding {
  Undecodable._() : super._();
}

/// Text that is no token of any format.
final class NotAToken extends Undecodable {
  /// The decoding of text that is no token.
  NotAToken() : super._();
}

/// A token of a format other than [Token.format], which this grit does not
/// read.
final class OtherFormat extends Undecodable {
  /// The decoding of a token of [format].
  OtherFormat(this.format) : super._();

  /// The format the token opens with, such as `grit2`.
  final String format;
}
