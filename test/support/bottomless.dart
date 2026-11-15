import 'package:grit/grit.dart';

/// A generator that draws itself inside itself and reads no choice, so its
/// draw recurses until the stack overflows.
final Gen<int> bottomless = .build((Draw draw) => 1 + draw(bottomless));

/// A generator that reads a choice up to 3, and draws [bottomless] where it
/// is above 0.
final Gen<int> overflowing = .build(
  (Draw draw) => draw(.integer(min: 0, max: 3)) > 0 ? draw(bottomless) : 0,
);
