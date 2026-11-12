/-!
A run's record of choices, and the shortlex order shrinking descends.
-/

namespace Grit

/-- The choices one run made, in order, each a natural number. -/
abbrev Seq := List Nat

/-- The largest choice the Dart VM's integers hold. -/
def largest : Nat := 2 ^ 63 - 1

/-- Whether `a` is smaller than `b` at their first difference, read over the two alike in length. -/
def lexLess : Seq → Seq → Bool
  | x :: xs, y :: ys => x < y || (x == y && lexLess xs ys)
  | _, _ => false

/-- Whether `a` is shortlex smaller than `b`: shorter, or the same length and smaller at its first difference. -/
def smaller (a b : Seq) : Bool :=
  if a.length = b.length then lexLess a b else a.length < b.length

end Grit
