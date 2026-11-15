import 'package:test/test.dart';

import 'doubles.dart';

/// Matches a value equal to [expected], where each double within it, alone or
/// at any depth of a list or a set, is the same double, -0.0 told from 0.0.
Matcher exactly(Object? expected) =>
    predicate((Object? actual) => _exactly(actual, expected), '$expected');

/// Whether [a] equals [b], each double within them the same double.
bool _exactly(Object? a, Object? b) => switch ((a, b)) {
  (final double a, final double b) => sameDouble(a, b),
  (final List<Object?> a, final List<Object?> b) =>
    a.length == b.length &&
        [for (int i = 0; i < a.length; i++) i]
            .every((int i) => _exactly(a[i], b[i])),
  (final Set<Object?> a, final Set<Object?> b) => _pairsOff(a, b),
  _ => a == b,
};

/// Whether each element of [a] pairs off with an element of [b] it
/// [_exactly] equals, none left over on either side.
///
/// [_exactly] is an equivalence, so pairing each with the first match left
/// never strands an element another pairing would have matched.
bool _pairsOff(Set<Object?> a, Set<Object?> b) {
  final List<Object?> left = [...b];
  for (final Object? x in a) {
    final int at = left.indexWhere((Object? y) => _exactly(x, y));
    if (at == -1) return false;
    left.removeAt(at);
  }
  return left.isEmpty;
}
