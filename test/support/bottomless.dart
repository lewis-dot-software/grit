import 'package:grit/grit.dart';

/// A generator that draws itself inside itself and reads no choice, so its
/// draw recurses until the stack overflows.
final Gen<int> bottomless = .build((Draw draw) => 1 + draw(bottomless));

/// A generator that reads a choice up to 3, and draws [bottomless] where it
/// is above 0.
final Gen<int> overflowing = .build(
  (Draw draw) => draw(.integer(min: 0, max: 3)) > 0 ? draw(bottomless) : 0,
);

/// A body that notes a line and calls itself, so it recurses outside any
/// draw until the stack overflows.
void notesBottomless(Draw draw) {
  draw.note('deeper');
  notesBottomless(draw);
}

/// A body that reads a choice up to 3, and calls [notesBottomless] where it
/// is above 0.
void notesOverflowing(Draw draw) {
  if (draw(.integer(min: 0, max: 3)) > 0) notesBottomless(draw);
}
