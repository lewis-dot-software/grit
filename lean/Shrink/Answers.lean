import Shrink.Step

/-!
Shrinking told an answer at each step: the states a step function passes through from a first failure, whatever the
oracle answers.
-/

namespace Grit

/-- The state of shrinking `first` by `start` and `told` after `n` steps, the candidate at step `k` told as failing
where `answers k` holds. A state that has ended stays as it is. -/
def after (start : Seq → Shrink) (told : Shrinking → Bool → Shrink) (first : Seq) (answers : Nat → Bool) :
    Nat → Shrink
  | 0 => start first
  | n + 1 =>
    match after start told first answers n with
    | .shrinking s => told s (answers n)
    | .shrunk current => .shrunk current

end Grit
