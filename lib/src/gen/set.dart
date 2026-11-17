part of 'gen.dart';

/// A set of [element]'s distinct values, from [minSize] to [maxSize] in size.
///
/// Each element sits behind a "one more" choice, and a draw that repeats an
/// element the set holds is drawn again, up to [_tries] draws in all. Once
/// those are spent the set ends where it stands, or rejects the run where it
/// holds fewer than [minSize].
Gen<Set<E>> _set<E>(
  Gen<E> element, {
  required int minSize,
  required int? maxSize,
}) {
  _checkSizes(minSize, maxSize, minName: 'minSize', noun: 'size');
  final double mean = _meanPast(minSize, maxSize);
  return ._((Draw draw) {
    final int start = draw._source.length;
    final Set<E> set = {};
    while (_more(
      draw,
      set.length,
      min: minSize,
      max: maxSize,
      start: start,
      mean: mean,
    )) {
      bool added = false;
      for (int i = 0; i < _tries && !added; i++) {
        added = set.add(draw(element));
      }
      if (added) continue;
      if (set.length < minSize) draw._source.reject();
      break;
    }
    return set;
  });
}
