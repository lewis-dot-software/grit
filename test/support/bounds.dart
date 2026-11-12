import 'package:grit/grit.dart';

/// A collection's minimum size and its maximum, null for none.
///
/// - `min`: the minimum, inclusive.
/// - `max`: the maximum, inclusive, or null where there is none.
typedef Bounds = ({int min, int? max});

/// A minimum from 0 to 4, and a maximum at most 8 above it, or none.
final Gen<Bounds> bounds = .build((Draw draw) {
  final int min = draw(.integer(min: 0, max: 4), label: 'minimum');
  final int? max = draw(.boolean())
      ? draw(
          .integer(min: min, max: min + 8),
          label: 'maximum',
        )
      : null;
  return (min: min, max: max);
});
