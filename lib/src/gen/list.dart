part of 'gen.dart';

/// The odds of one more element past a list's minimum, which put five more
/// on average where no maximum cuts the list short.
final Odds _oneMore = .new(5 / 6);

/// The bound of the choice a list at its maximum ends on, which can only be
/// 0.
final Bound _ended = .new(0);

/// A list of [element]'s values, from [minLength] to [maxLength] long.
///
/// Each element sits behind a "one more" choice, read as one more whatever
/// it holds until the list reaches [minLength], and the list ends on a choice
/// of 0, so deleting any one element's span from the record of a list longer
/// than [minLength] deletes that element whole.
Gen<List<E>> _list<E>(
  Gen<E> element, {
  required int minLength,
  required int? maxLength,
}) {
  RangeError.checkNotNegative(minLength, 'minLength');
  if (maxLength != null && maxLength < minLength) {
    throw ArgumentError(
      'The minimum length $minLength is above the maximum $maxLength',
    );
  }

  bool more(Draw draw, int length) {
    if (length < minLength) {
      // An element inside the minimum still sits behind a choice, so deleting
      // an earlier element's span leaves each later one behind a choice as
      // well.
      draw._source.weigh(_oneMore);
      return true;
    }
    if (length == maxLength) {
      // A list at its maximum still ends on a choice, as a shorter one does,
      // so deleting an element's span leaves a record that ends where the
      // shorter list does.
      draw._source.choose(_ended);
      return false;
    }
    return draw._source.weigh(_oneMore);
  }

  return ._((Draw draw) {
    final List<E> list = [];
    while (more(draw, list.length)) {
      list.add(draw(element));
    }
    return list;
  });
}
