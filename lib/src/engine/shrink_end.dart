/// What ended a shrinking.
enum ShrinkEnd {
  /// The step function ended: a round of every pass accepted nothing.
  shrunk,

  /// The budget's bound on steps ran out.
  steps,

  /// The budget's bound on time ran out.
  time,
}
