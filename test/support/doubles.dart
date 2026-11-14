import 'dart:typed_data';

import 'package:grit/grit.dart';

/// The doubles at the seams a float's encoding turns on: each zero, the
/// smallest subnormal and the smallest normal, the edges of 1, of 2 to the
/// 52 and of 2 to the 53, the largest finite double, each infinity and NaN,
/// of both signs.
final List<double> seams = [
  for (final double magnitude in [
    0,
    .minPositive,
    2.2250738585072014e-308,
    0.5,
    1,
    1.5,
    4503599627370495.5,
    4503599627370496,
    9007199254740991,
    9007199254740992,
    9007199254740994,
    .maxFinite,
    .infinity,
  ]) ...[magnitude, -magnitude],
  .nan,
];

/// The double of [bits].
double doubleOf(int bits) => (ByteData(8)..setInt64(0, bits)).getFloat64(0);

/// The bits of [value].
int bitsOf(double value) => (ByteData(8)..setFloat64(0, value)).getInt64(0);

/// The double after [value], which is neither NaN nor positive infinity, in
/// the order that puts -0.0 below 0.0.
double nextUp(double value) => switch (value) {
  0 when value.isNegative => 0,
  _ when value.isNegative => doubleOf(bitsOf(value) - 1),
  _ => doubleOf(bitsOf(value) + 1),
};

/// Whether [a] and [b] are the same double, -0.0 told from 0.0, and every
/// NaN alike.
bool sameDouble(double a, double b) =>
    (a.isNaN && b.isNaN) || (a == b && a.isNegative == b.isNegative);

/// The largest bits a double of positive sign has short of NaN, those of
/// positive infinity.
const int _infinityBits = 2047 << 52;

/// A double of any bits short of NaN's, either sign, or one at a seam, NaN
/// among them.
///
/// Its simplest value is 0.0.
final Gen<double> anyDouble = .oneOf([
  .element(seams),
  .build((Draw draw) {
    final double magnitude = doubleOf(
      draw(.integer(min: 0, max: _infinityBits)),
    );
    return draw(.boolean()) ? -magnitude : magnitude;
  }),
]);
