part of 'gen.dart';

/// A value of one of [generators], one choice of its index, then that
/// generator's draw.
Gen<T> _oneOf<T>(Iterable<Gen<T>> generators) {
  final List<Gen<T>> options = .unmodifiable(generators);
  if (options.isEmpty) {
    throw ArgumentError.value(
      generators,
      'generators',
      'Must hold at least one',
    );
  }
  final Bound bound = .new(options.length - 1);
  return ._((Draw draw) => draw(options[draw._source.choose(bound).value]));
}
