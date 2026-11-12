/// The bounds on one shrinking.
///
/// - `steps`: the most candidates shrinking runs, never negative.
/// - `time`: the longest shrinking may take from its start, by the search's
///   clock, never negative.
typedef Budget = ({int steps, Duration time});
