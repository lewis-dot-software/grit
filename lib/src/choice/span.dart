/// The stretch of a run's record one draw made, beside the draws around it.
///
/// A run's spans are listed in the order their draws began, so the spans
/// beneath a draw's follow it, each deeper than it.
///
/// - `start`: the place in the record of the draw's first choice.
/// - `width`: how many choices the draw made, those beneath it among them.
/// - `depth`: how many draws were in progress around it, 0 for one the
///   property's body made.
typedef Span = ({int start, int width, int depth});
