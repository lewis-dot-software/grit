/-!
A run's record of choices, the span of each draw it made, and the shortlex order shrinking descends.
-/

namespace Grit

/-- The choices one run made, in order, each a natural number. -/
abbrev Seq := List Nat

/-- The largest choice the Dart VM's integers hold. -/
def largest : Nat := 2 ^ 63 - 1

/-- The stretch of a run's record one draw made: `width` choices from `start`, with `depth` draws in progress around
it, and the choices its generator names as a simpler value to take its place, where it names one. A run's spans are
listed in the order their draws began. -/
structure Span where
  start : Nat
  width : Nat
  depth : Nat
  form : Option Seq
  deriving DecidableEq, Repr

/-- Whether `a` is smaller than `b` at their first difference, read over the two alike in length. -/
def lexLess (a b : Seq) : Bool :=
  match a, b with
  | x :: xs, y :: ys => x < y || (x == y && lexLess xs ys)
  | _, _ => false

/-- Whether `a` is shortlex smaller than `b`: shorter, or the same length and smaller at its first difference. -/
def smaller (a b : Seq) : Bool :=
  if a.length = b.length then lexLess a b else a.length < b.length

end Grit
