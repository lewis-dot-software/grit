import 'package:grit/grit.dart';
import 'package:grit/src/choice/zigzag.dart';
import 'package:test/test.dart';

import '../support/inputs.dart';

/// The most distances on either side the exhaustive checks reach.
const int _side = 6;

/// Every zigzag of up to [_side] distances on either side.
Iterable<Zigzag> _everySmallZigzag() sync* {
  for (int below = 0; below <= _side; below++) {
    for (int above = 0; above <= _side; above++) {
      yield .new(below: below, above: above);
    }
  }
}

/// The distance each choice of [zigzag] stands for, by choice.
List<int> _distances(Zigzag zigzag) => [
  for (int choice = 0; choice <= zigzag.bound.value; choice++)
    zigzag.distance(.new(choice)),
];

void main() {
  test('stands for distances above its centre first, then below, until one '
      'side runs out, then on along the other', () {
    expect(_distances(.new(below: 2, above: 2)), [0, 1, -1, 2, -2]);
    expect(_distances(.new(below: 1, above: 3)), [0, 1, -1, 2, 3]);
    expect(_distances(.new(below: 3, above: 1)), [0, 1, -1, -2, -3]);
  });

  test('counting a bound stands for each choice as its own distance', () {
    expect(_distances(.counting(.new(4))), [0, 1, 2, 3, 4]);
  });

  test('names the choice of the end its bound does not stand for, or none '
      'where it has one side alone', () {
    expect(Zigzag(below: 2, above: 5).otherEnd, Choice(4));
    expect(Zigzag(below: 5, above: 2).otherEnd, Choice(3));
    expect(Zigzag(below: 3, above: 3).otherEnd, Choice(5));
    expect(Zigzag(below: 0, above: 3).otherEnd, isNull);
    expect(Zigzag(below: 3, above: 0).otherEnd, isNull);
  });

  test('reaches both ends of the widest zigzag a choice holds', () {
    final Zigzag widest = .new(
      below: 1 << 62,
      above: Choice.largest.value - (1 << 62),
    );
    final Choice otherEnd = widest.otherEnd!;
    expect(widest.distance(.new(widest.bound.value)), -(1 << 62));
    expect(widest.distance(otherEnd), Choice.largest.value - (1 << 62));
    expect(widest.at(-(1 << 62)), Choice(widest.bound.value));
    expect(widest.at(Choice.largest.value - (1 << 62)), otherEnd);
  });

  group('over every small zigzag', () {
    test('ENG-17: A zigzag stands for each distance from below its centre '
        'to above it at exactly one choice, which it finds from the '
        'distance.', () {
      for (final Zigzag zigzag in _everySmallZigzag()) {
        final List<int> distances = _distances(zigzag);
        expect(distances.toSet(), {
          for (int d = -zigzag.below; d <= zigzag.above; d++) d,
        }, reason: '$zigzag: $distances');
        for (final (int choice, int distance) in distances.indexed) {
          expect(zigzag.at(distance), Choice(choice), reason: '$zigzag');
        }
      }
    });

    test('ENG-18: A larger choice never stands for a distance nearer the '
        'centre.', () {
      for (final Zigzag zigzag in _everySmallZigzag()) {
        final List<int> distances = _distances(zigzag);
        for (int choice = 1; choice < distances.length; choice++) {
          expect(
            distances[choice - 1].abs(),
            lessThanOrEqualTo(distances[choice].abs()),
            reason: '$zigzag: $distances',
          );
        }
      }
    });

    test("ENG-19: A zigzag's bound and its other end, beside its centre "
        'at 0, stand for its two ends.', () {
      // A zigzag with one side alone has its centre for its other end.
      for (final Zigzag zigzag in _everySmallZigzag()) {
        final Set<int> ends = {
          zigzag.distance(.new(0)),
          zigzag.distance(.new(zigzag.bound.value)),
          ?switch (zigzag.otherEnd) {
            final Choice otherEnd => zigzag.distance(otherEnd),
            null => null,
          },
        };
        expect(ends, {0, -zigzag.below, zigzag.above}, reason: '$zigzag');
      }
    });
  });

  group('a bug in grit', () {
    test('a negative side is thrown', () {
      expect(() => Zigzag(below: -1, above: 0), throwsRangeError);
      expect(() => Zigzag(below: 0, above: -1), throwsRangeError);
    });

    test('sides holding more distances than a choice does are thrown', () {
      expect(
        () => Zigzag(below: 1, above: Choice.largest.value),
        throwsRangeError,
      );
      expect(
        () => Zigzag(below: Choice.largest.value, above: 1),
        throwsRangeError,
      );
    });
  });

  group('on grit, over larger inputs', () {
    property('ENG-17: A zigzag stands for each distance from below its '
        'centre to above it at exactly one choice, which it finds '
        'from the distance.', (Draw draw) {
      // Each choice standing for a distance in range that leads back to it,
      // and each distance in range leading to a choice that stands for it,
      // is one choice per distance.
      final Zigzag zigzag = draw(anyZigzag, label: 'zigzag');
      final Choice choice = .new(
        draw(.integer(min: 0, max: zigzag.bound.value), label: 'choice'),
      );
      final int distance = zigzag.distance(choice);
      expect(distance, inInclusiveRange(-zigzag.below, zigzag.above));
      expect(zigzag.at(distance), choice);
      final int other = draw(
        .integer(min: -zigzag.below, max: zigzag.above),
        label: 'distance',
      );
      final Choice at = zigzag.at(other);
      expect(zigzag.bound.admits(at), isTrue);
      expect(zigzag.distance(at), other);
    });

    property('ENG-18: A larger choice never stands for a distance nearer '
        'the centre.', (Draw draw) {
      final Zigzag zigzag = draw(anyZigzag, label: 'zigzag');
      final int larger = draw(
        .integer(min: 0, max: zigzag.bound.value),
        label: 'larger',
      );
      final int smaller = draw(.integer(min: 0, max: larger), label: 'smaller');
      expect(
        zigzag.distance(.new(smaller)).abs(),
        lessThanOrEqualTo(zigzag.distance(.new(larger)).abs()),
      );
    });

    property("ENG-19: A zigzag's bound and its other end, beside its "
        'centre at 0, stand for its two ends.', (Draw draw) {
      final Zigzag zigzag = draw(anyZigzag, label: 'zigzag');
      final Set<int> ends = {
        zigzag.distance(.new(0)),
        zigzag.distance(.new(zigzag.bound.value)),
        ?switch (zigzag.otherEnd) {
          final Choice otherEnd => zigzag.distance(otherEnd),
          null => null,
        },
      };
      expect(ends, {0, -zigzag.below, zigzag.above});
    });
  });
}
