part of 'gen.dart';

/// How many elements past its minimum size a collection is drawn for on
/// average, where no maximum sets a mean of more.
const double _leastMean = 5;

/// How many elements past [min] a collection from [min] to [max] in size is
/// drawn for on average: half its range, or [_leastMean] where that is more
/// or no [max] is given.
double _meanPast(int min, int? max) => switch (max) {
  null => _leastMean,
  final int max => math.max(_leastMean, (max - min) / 2),
};

/// The odds of one more element for a collection [size] elements in, up to
/// [max] in size, whose record began at [start], drawn for [mean] elements
/// past its minimum.
///
/// Odds p put p / (1 - p) more elements on average where nothing cuts them
/// short. Where the run's room fits every element up to [max] at the choices
/// each so far has cost, nothing does, since the collection ends at [max]
/// inside the run. Elsewhere [mean] is cut to as many elements as the room
/// still fits, and the odds are never where it fits fewer than two. An
/// element not yet drawn is priced at one choice, so a collection whose
/// elements each cost alike ends inside the run, however many of its "one
/// more" choices are filled as one more, wherever the room it starts with
/// fits its minimum, or one element where that is 0, and a choice more.
Odds _oneMore(
  ChoiceSource source,
  int size, {
  required int? max,
  required int start,
  required double mean,
}) {
  final double cost = size == 0 ? 1 : (source.length - start) / size;
  final double fits = source.room / cost;
  if (max != null && fits > max - size) return .new(mean / (mean + 1));
  if (fits < 2) return .never;
  final double cut = math.min(mean, fits);
  return .new(cut / (cut + 1));
}

/// Whether a collection [size] elements in, from [min] to [max] in size and
/// drawn for [mean] elements past [min], takes one more element, read from
/// its "one more" choice. Its record began at [start].
///
/// An element inside [min] still sits behind a choice, read as one more
/// whatever it holds, so deleting an earlier element's span leaves each later
/// one behind a choice as well. A collection at [max] still ends on a choice,
/// one that can only be 0, so deleting an element's span leaves a record that
/// ends where the smaller collection does.
bool _more(
  Draw draw,
  int size, {
  required int min,
  required int? max,
  required int start,
  required double mean,
}) {
  final ChoiceSource source = draw._source;
  if (size < min) {
    source.weigh(_oneMore(source, size, max: max, start: start, mean: mean));
    return true;
  }
  if (size == max) {
    source.choose(.zero);
    return false;
  }
  return source.weigh(
    _oneMore(source, size, max: max, start: start, mean: mean),
  );
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
