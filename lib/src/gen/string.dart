part of 'gen.dart';

/// A string of [alphabet]'s characters, from [minLength] to [maxLength] code
/// points long.
///
/// A list of code points, each one choice of its index in [alphabet] behind
/// a "one more" choice, so deleting a code point's span deletes it whole.
Gen<String> _string(
  Alphabet alphabet, {
  required int minLength,
  required int? maxLength,
}) {
  final Bound bound = .new(alphabet._size - 1);
  final Gen<int> codePoint = ._(
    (Draw draw) => alphabet._codePointAt(draw._source.choose(bound).value),
  );
  return _list(
    codePoint,
    minLength: minLength,
    maxLength: maxLength,
  ).map(String.fromCharCodes);
}
