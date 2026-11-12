part of 'gen.dart';

/// One value a property's body drew.
///
/// - `label`: the label the body drew it under, or null where it named none.
/// - `value`: the value the draw returned, which the body may since have
///   changed in place.
/// - `text`: the value's text as the draw returned it.
typedef Drawn = ({String? label, Object? value, String text});
