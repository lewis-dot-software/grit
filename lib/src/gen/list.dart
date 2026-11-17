part of 'gen.dart';

/// A list of [element]'s values, from [minLength] to [maxLength] long.
///
/// Each element sits behind a "one more" choice, and the list ends on a
/// choice of 0, so deleting any one element's span from the record of a list
/// longer than [minLength] deletes that element whole.
Gen<List<E>> _list<E>(
  Gen<E> element, {
  required int minLength,
  required int? maxLength,
}) {
  _checkSizes(minLength, maxLength, minName: 'minLength', noun: 'length');
  final double mean = _meanPast(minLength, maxLength);
  return ._((Draw draw) {
    final int start = draw._source.length;
    final List<E> list = [];
    while (_more(
      draw,
      list.length,
      min: minLength,
      max: maxLength,
      start: start,
      mean: mean,
    )) {
      list.add(draw(element));
    }
    return list;
  });
}
