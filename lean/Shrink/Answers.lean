import Shrink.Step

/-!
Shrinking told an answer at each step: the states a step function passes through from a first failure, whatever the
oracle answers.
-/

namespace Grit

/-- The state `told` reaches from `state` after `steps` steps, each candidate told the answer `answers` gives the
number of its step, from 0. A state that has ended stays as it is. -/
def walk (told : Shrinking → Answer → Shrink) (state : Shrink) (answers : Nat → Answer) (steps : Nat) : Shrink :=
  match steps with
  | 0 => state
  | n + 1 =>
    match walk told state answers n with
    | .shrinking s => told s (answers n)
    | .shrunk current => .shrunk current

/-- The state of shrinking `first`, whose run made `spans`, by `start` and `told` after `steps` steps, each candidate
told the answer `answers` gives the number of its step, from 0. -/
def after (start : Seq → List Span → Shrink) (told : Shrinking → Answer → Shrink) (first : Seq) (spans : List Span)
    (answers : Nat → Answer) (steps : Nat) : Shrink :=
  walk told (start first spans) answers steps

theorem after_succ {start told first spans answers n} :
    after start told first spans answers (n + 1) =
      match after start told first spans answers n with
      | .shrinking s => told s (answers n)
      | .shrunk current => .shrunk current :=
  rfl

end Grit
