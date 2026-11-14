import '../choice/decoding.dart';
import '../choice/token.dart';

/// Why text decoded as [reason], as a clause that reads on from the text it
/// is said of.
String undecodableText(Undecodable reason) => switch (reason) {
  NotAToken() => 'is no grit token',
  OtherFormat(:final String format) =>
    'is a token of format `$format`, and this grit reads `${Token.format}` '
        'alone',
};
