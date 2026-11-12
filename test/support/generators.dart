import 'package:grit/grit.dart';

import 'alphabets.dart';
import 'generator.dart';
import 'predicate.dart';

/// A generator of `.integer`, `.boolean`, `.element`, `.list`, `.string`,
/// `.oneOf` or `.set`, with the simplest value its docs give it.
typedef Simple = ({Generator generator, Object? simplest});

/// The largest magnitude a range's ends reach at each of its scales, the
/// widest of which still holds no more values than a choice does.
final List<int> _magnitudes = [3, 255, 0xFFFFFFFF, (1 << 62) - 1];

/// A range of integers, its minimum and maximum, at one of a few scales,
/// either side of 0 or across it.
final Gen<(int, int)> integerRange = .build((Draw draw) {
  final int magnitude = draw(.element(_magnitudes));
  final Gen<int> end = .integer(min: -magnitude, max: magnitude);
  final int a = draw(end);
  final int b = draw(end);
  return a <= b ? (a, b) : (b, a);
});

/// The kinds of generator [simpleGenerator] draws.
enum _Simple { integer, boolean, element, list, string, oneOf, set }

/// The kinds of [_Simple] built on other generators.
const Set<_Simple> _nested = {.list, .oneOf, .set};

/// A generator of `.integer`, `.boolean`, `.element`, `.list`, `.string`,
/// `.oneOf` or `.set`, one built on others itself built on others at most
/// twice over.
final Gen<Simple> simpleGenerator = _simple(2);

Gen<Simple> _simple(int depth) => .build((Draw draw) {
  final _Simple kind = draw(
    .element([
      for (final _Simple kind in _Simple.values)
        if (!_nested.contains(kind) || depth > 0) kind,
    ]),
  );
  switch (kind) {
    case .integer:
      final (int min, int max) = draw(integerRange);
      return (
        generator: .new(
          'an integer from $min to $max',
          .integer(min: min, max: max),
        ),
        simplest: 0.clamp(min, max),
      );
    case .boolean:
      return (generator: .new('a boolean', .boolean()), simplest: false);
    case .element:
      final List<int> values = draw(
        .list(.integer(min: -9, max: 9), minLength: 1),
      );
      return (
        generator: .new('an element of $values', .element(values)),
        simplest: values.first,
      );
    case .list:
      final Simple element = draw(_simple(depth - 1));
      final int minLength = draw(.integer(min: 0, max: 4));
      final int? maxLength = draw(.boolean())
          ? minLength + draw(.integer(min: 0, max: 4))
          : null;
      return (
        generator: .new(
          'a list of ${element.generator}, from $minLength to '
          '${maxLength ?? 'any number'} long',
          .list(
            element.generator.gen,
            minLength: minLength,
            maxLength: maxLength,
          ),
        ),
        simplest: List<Object?>.filled(minLength, element.simplest),
      );
    case .string:
      final Letters letters = draw(.element(presets));
      final int minLength = draw(.integer(min: 0, max: 4));
      final int? maxLength = draw(.boolean())
          ? minLength + draw(.integer(min: 0, max: 4))
          : null;
      return (
        generator: .new(
          'a string of ${letters.name}, from $minLength to '
          '${maxLength ?? 'any number'} long',
          .string(
            alphabet: letters.alphabet,
            minLength: minLength,
            maxLength: maxLength,
          ),
        ),
        simplest: letters.simplest * minLength,
      );
    case .oneOf:
      final List<Simple> options = draw(
        .list(_simple(depth - 1), minLength: 1, maxLength: 3),
      );
      return (
        generator: .new(
          'one of ${[for (final Simple option in options) option.generator]}',
          .oneOf([for (final Simple option in options) option.generator.gen]),
        ),
        simplest: options.first.simplest,
      );
    case .set:
      // A set's simplest value is documented only at a minimum size of 0.
      final Simple element = draw(_simple(depth - 1));
      final int? maxSize = draw(.boolean())
          ? draw(.integer(min: 0, max: 4))
          : null;
      return (
        generator: .new(
          'a set of ${element.generator}, up to ${maxSize ?? 'any number'}',
          .set(element.generator.gen, maxSize: maxSize),
        ),
        simplest: <Object?>{},
      );
  }
});

/// The kinds of generator [anyGenerator] draws.
enum _Any { simple, map, filter, build }

/// A generator of any kind the stage has, each built on the others at most
/// twice over: one of [simpleGenerator]'s, or one mapped, filtered or built
/// from another.
final Gen<Generator> anyGenerator = _any(2);

Gen<Generator> _any(int depth) => .build((Draw draw) {
  final _Any kind = depth > 0 ? draw(.element(_Any.values)) : .simple;
  switch (kind) {
    case .simple:
      return draw(simpleGenerator).generator;
    case .map:
      final Generator base = draw(_any(depth - 1));
      return .new('the text of $base', base.gen.map((Object? v) => '$v'));
    case .filter:
      final Generator base = draw(_any(depth - 1));
      final Predicate predicate = draw(.element(Predicate.values));
      return .new(
        '$base, filtered to ${predicate.name}',
        base.gen.filter(predicate.accepts),
      );
    case .build:
      final Generator base = draw(_any(depth - 1));
      return .new(
        'up to 3 of $base, as many as drawn first',
        .build((Draw draw) {
          final int count = draw(.integer(min: 0, max: 3));
          return [for (int i = 0; i < count; i++) draw(base.gen)];
        }),
      );
  }
});
