import Shrink.Pass

/-!
The step function: a state of shrinking proposes a candidate and is told whether its run failed as the first failure
did, as the Dart's `Shrink` steps.
-/

namespace Grit

/-- A state that proposes `candidate` and waits to be told whether its run failed. -/
structure Shrinking where
  /-- The smallest sequence told as failing so far, or the first failure where none has been. -/
  current : Seq
  /-- The sequence to run next. -/
  candidate : Seq
  /-- The pass that proposed `candidate`. -/
  pass : Pass
  /-- How many candidates `pass` proposes from `current` before `candidate`. -/
  position : Nat
  /-- The candidates `pass` proposes from `current` after `candidate`. -/
  rest : List Seq
  /-- Whether this round has accepted a candidate yet. -/
  accepted : Bool

/-- One state of shrinking: proposing a candidate, or ended on its current sequence. -/
inductive Shrink where
  | shrinking (s : Shrinking)
  | shrunk (current : Seq)

/-- The smallest sequence told as failing so far, or the first failure where none has been. -/
def Shrink.current : Shrink → Seq
  | .shrinking s => s.current
  | .shrunk current => current

/-- The state proposing the first of `cs` smaller than `current`, the first of `cs` at `position` among the candidates
`pass` proposes, or none where no candidate of `cs` is smaller. -/
def firstSmaller (current : Seq) (pass : Pass) (accepted : Bool) : Nat → List Seq → Option Shrinking
  | _, [] => none
  | position, c :: cs =>
    if smaller c current then some ⟨current, c, pass, position, cs, accepted⟩
    else firstSmaller current pass accepted (position + 1) cs

/-- The state proposing the first candidate smaller than `current` that any of `passes` proposes, the passes taken in
order, or none where none proposes one. -/
def inPasses (current : Seq) (accepted : Bool) : List Pass → Option Shrinking
  | [] => none
  | p :: ps =>
    match firstSmaller current p accepted 0 (p.candidates current) with
    | some s => some s
    | none => inPasses current accepted ps

/-- The first state from the candidates `cs` of `pass` on, the first at `position`, that proposes a candidate smaller
than `current`, moving through the later passes and into a new round as each runs out, or ended where a round ends with
nothing `accepted`. -/
def seek (current : Seq) (pass : Pass) (position : Nat) (cs : List Seq) (accepted : Bool) : Shrink :=
  match firstSmaller current pass accepted position cs with
  | some s => .shrinking s
  | none =>
    match inPasses current accepted pass.later with
    | some s => .shrinking s
    | none =>
      if accepted then
        match inPasses current false Pass.all with
        | some s => .shrinking s
        | none => .shrunk current
      else .shrunk current

/-- The first state of shrinking `first`, a sequence whose run failed. -/
def start (first : Seq) : Shrink :=
  seek first .deleteSpan 0 (Pass.deleteSpan.candidates first) false

/-- The state after `s`'s candidate's run, which `failed` as the first failure did or not. -/
def told (s : Shrinking) (failed : Bool) : Shrink :=
  if failed then seek s.candidate s.pass s.position ((s.pass.candidates s.candidate).drop s.position) true
  else seek s.current s.pass (s.position + 1) s.rest s.accepted

end Grit
