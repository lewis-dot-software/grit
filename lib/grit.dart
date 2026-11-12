/// Property-based testing for Dart: a property's body draws its inputs, grit
/// searches for a failing case, and shrinks it to its smallest within a
/// budget.
library;

export 'src/api/for_all.dart';
export 'src/api/property.dart';
export 'src/api/run_property.dart';
export 'src/api/settings.dart';
export 'src/choice/choice.dart';
export 'src/choice/choice_sequence.dart';
export 'src/engine/failure.dart';
export 'src/engine/frame.dart';
export 'src/engine/outcome.dart';
export 'src/engine/run.dart';
export 'src/engine/search.dart' show Body;
export 'src/engine/shrink_end.dart';
export 'src/gen/gen.dart';
