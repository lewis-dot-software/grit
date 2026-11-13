import 'bound.dart';
import 'choice.dart';
import 'choice_sequence.dart';

/// A choice that names edges, told from another by both:
///
/// - `bound`: the bound it is asked for under.
/// - `edges`: the edges it names, in order.
typedef NamedChoice = ({Bound bound, ChoiceSequence edges});

/// A named choice at its place in its run:
///
/// - `choice`: the choice.
/// - `alike`: how many choices alike its run made before it.
typedef _Place = ({NamedChoice choice, int alike});

/// Which of its named edges each choice of a search's early runs is filled
/// at next, so a choice is filled at each edge it names, in the order it
/// names them, in the first runs that make it.
///
/// A choice is told from another by its bound, the edges it names and its
/// place among the choices alike in both that its run made before it.
final class Sweep {
  /// How many of its named edges each choice has been filled at so far.
  final Map<_Place, int> _filled = {};

  /// The named edge [choice], with [alike] choices alike before it in its
  /// run, is filled at, or null where it names none or has been filled at
  /// each.
  Choice? next(NamedChoice choice, {required int alike}) {
    final _Place place = (choice: choice, alike: alike);
    final int filled = _filled[place] ?? 0;
    if (filled >= choice.edges.choices.length) return null;
    _filled[place] = filled + 1;
    return choice.edges.choices[filled];
  }
}
