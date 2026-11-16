import 'package:grit/grit.dart';
import 'package:test/test.dart';

import '../support/challenge.dart';

/// A finite double, as grid sizes and positions are drawn.
final Gen<double> _finite = .float(nan: false, infinite: false);

/// Doubles whose failures turn on a magnitude, each held to the smallest
/// whole number that fails as a challenge is held to its smallest known.
void main() {
  challenge('a fraction must stay below 3.5', (Draw draw) {
    expect(draw(.float(min: 0.25, max: 1e6)), lessThan(3.5));
  }, [4.0]);
  challenge("a double's magnitude must stay below 1e10", (Draw draw) {
    expect(draw(.float()).abs() >= 1e10, isFalse);
  }, [1e10]);
  challenge(
    'two doubles over a third must not overflow',
    (Draw draw) {
      final double x = draw(_finite);
      final double y = draw(_finite);
      final double size = draw(_finite);
      expect(size <= 0 || (x / size).isFinite && (y / size).isFinite, isTrue);
    },
    [0.0, 1.0, double.minPositive],
    moreSeeds: [15, 17, 19],
  );
}
