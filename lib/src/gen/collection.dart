part of 'gen.dart';

/// The odds of one more element past a collection's minimum size, which put
/// five more on average where no maximum cuts it short.
final Odds _oneMore = .new(5 / 6);

/// Whether a collection [size] elements in, from [min] to [max] in size, takes
/// one more element, read from its "one more" choice.
///
/// An element inside [min] still sits behind a choice, read as one more
/// whatever it holds, so deleting an earlier element's span leaves each later
/// one behind a choice as well. A collection at [max] still ends on a choice,
/// one that can only be 0, so deleting an element's span leaves a record that
/// ends where the smaller collection does.
bool _more(Draw draw, int size, {required int min, required int? max}) {
  if (size < min) {
    draw._source.weigh(_oneMore);
    return true;
  }
  if (size == max) {
    draw._source.choose(.zero);
    return false;
  }
  return draw._source.weigh(_oneMore);
}

/// Throws where [min], the collection's minimum [noun] named [minName], is
/// negative or above [max].
void _checkSizes(
  int min,
  int? max, {
  required String minName,
  required String noun,
}) {
  RangeError.checkNotNegative(min, minName);
  if (max != null && max < min) {
    throw ArgumentError('The minimum $noun $min is above the maximum $max');
  }
}
