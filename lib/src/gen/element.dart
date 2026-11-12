part of 'gen.dart';

/// One of [values], one choice of its index.
Gen<T> _element<T>(Iterable<T> values) {
  final List<T> options = .unmodifiable(values);
  if (options.isEmpty) {
    throw ArgumentError.value(values, 'values', 'Must hold at least one');
  }
  final Bound bound = .new(options.length - 1);
  return ._((Draw draw) => options[draw._source.choose(bound).value]);
}
