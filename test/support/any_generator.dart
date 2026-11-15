import 'package:grit/grit.dart';

import 'generator.dart';
import 'predicate.dart';
import 'simple_generator.dart';

/// The kinds of generator [anyGenerator] draws.
enum _Any { simple, map, filter, build }

/// A generator of any kind grit has, each built on the others at most
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
