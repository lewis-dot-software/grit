import 'package:grit/grit.dart';

import 'alphabets.dart';
import 'generator.dart';
import 'integer_range.dart';

/// A generator of `.integer`, `.boolean`, `.element`, `.list`, `.string`,
/// `.oneOf`, `.set` or `.float`, with the simplest value its docs give it.
typedef Simple = ({Generator generator, Object? simplest});

/// A float's range, with the simplest double in it.
///
/// - `min`: the minimum.
/// - `max`: the maximum.
/// - `simplest`: the simplest double from `min` to `max`.
typedef _Float = ({double min, double max, double simplest});

/// Ranges of a float, none drawing NaN, since NaN equals nothing by `==`,
/// nor by `equals` in a `matcher` before 0.12.18, which `test`'s floor
/// admits.
final List<_Float> _floats = [
  (min: .negativeInfinity, max: .infinity, simplest: 0),
  (min: 0.5, max: 3.25, simplest: 1),
  (min: 0.25, max: 0.75, simplest: 0.25),
  (min: -3.25, max: -0.5, simplest: -1),
  (min: -0.0, max: -0.0, simplest: -0.0),
  (min: .infinity, max: .infinity, simplest: .infinity),
];

/// The kinds of generator [simpleGenerator] draws.
enum _Simple { integer, boolean, element, list, string, oneOf, set, float }

/// The kinds of [_Simple] built on other generators.
const Set<_Simple> _nested = {.list, .oneOf, .set};

/// A generator of `.integer`, `.boolean`, `.element`, `.list`, `.string`,
/// `.oneOf`, `.set` or `.float`, one built on others itself built on others
/// at most twice over.
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
      final (:int min, :int max) = draw(integerRange);
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
      // A set's simplest value is documented only at a minimum size of 0
      // and 1.
      final Simple element = draw(_simple(depth - 1));
      final int minSize = draw(.integer(min: 0, max: 1));
      final int? maxSize = draw(.boolean())
          ? draw(.integer(min: minSize, max: 4))
          : null;
      return (
        generator: .new(
          'a set of ${element.generator}, from $minSize up to '
          '${maxSize ?? 'any number'}',
          .set(element.generator.gen, minSize: minSize, maxSize: maxSize),
        ),
        simplest: <Object?>{if (minSize == 1) element.simplest},
      );
    case .float:
      final (:double min, :double max, :double simplest) = draw(
        .element(_floats),
      );
      return (
        generator: .new(
          'a float from $min to $max',
          .float(min: min, max: max, nan: false),
        ),
        simplest: simplest,
      );
  }
});
