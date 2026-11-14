import 'package:grit/grit.dart';
import 'package:grit/src/choice/choice_source.dart';
import 'package:grit/src/choice/span.dart';
import 'package:grit/src/gen/gen.dart';

import 'small.dart';

/// A tree, each node one choice of how many nodes it holds, its value
/// modulo 3, then those nodes, so its record's spans nest and sit beside one
/// another as a structured value's do.
///
/// Its simplest value is a single node, holding none.
final Gen<void> _tree = .build((Draw draw) {
  final int children = draw(.integer(min: 0, max: Choice.largest.value)) % 3;
  for (int i = 0; i < children; i++) {
    draw(_tree);
  }
});

/// The spans a run of a tree over [sequence]'s choices alone makes, those of
/// the draws it stopped in among them, so any sequence has spans that nest
/// as a run's do.
List<Span> spansOf(ChoiceSequence sequence) {
  final ChoiceSource source = .fixed(sequence);
  final RunDraw draw = .new(source);
  run(source, () => draw(_tree));
  return draw.spans;
}
