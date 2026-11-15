part of 'gen.dart';

/// One value a property's body drew.
///
/// - `label`: the label the body drew it under, or null where it named none.
/// - `value`: the value the draw returned, which the body may since have
///   changed in place.
/// - `text`: the value's text as the draw returned it. A string is written as
///   a Dart literal whose every character shows, and so is each string a
///   list, a set or a map holds, at any depth of them. Any other value is
///   written as its own `toString`, a string inside it bare.
typedef Drawn = ({String? label, Object? value, String text});
