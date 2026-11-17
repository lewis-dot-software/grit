import Shrink.Pass

/-!
The step function: a state of shrinking proposes a candidate and is told whether its run failed as the first failure
did, and where it did, how many of its choices the run read and the spans the run made.
-/

namespace Grit

/-- What a candidate's run is told as: failing as the first failure did, having read `read` of its choices and made
`spans`, or not failing. -/
inductive Answer where
  | failing (read : Nat) (spans : List Span)
  | notFailing

/-- The record a run on `candidate` made, having read `read` of its choices: the first `read` of them, or every one
where `read` passes its length. -/
def record (candidate : Seq) (read : Nat) : Seq := candidate.take read

/-- A state that proposes `candidate` and waits to be told whether its run failed. -/
structure Shrinking where
  /-- The record of the latest run told as failing, or the first failure where none has been. -/
  current : Seq
  /-- The spans `current`'s run made. -/
  spans : List Span
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

/-- The record of the latest run told as failing, or the first failure where none has been. -/
def Shrink.current : Shrink → Seq
  | .shrinking s => s.current
  | .shrunk current => current

/-- The state proposing the first of `cs` smaller than `current`, whose run made `spans`, the first of `cs` at
`position` among the candidates `pass` proposes, or none where no candidate of `cs` is smaller. -/
def firstSmaller (current : Seq) (spans : List Span) (pass : Pass) (accepted : Bool) (position : Nat)
    (cs : List Seq) : Option Shrinking :=
  match cs with
  | [] => none
  | c :: rest =>
    if smaller c current then some ⟨current, spans, c, pass, position, rest, accepted⟩
    else firstSmaller current spans pass accepted (position + 1) rest

/-- The state proposing the first candidate smaller than `current`, whose run made `spans`, that any of `passes`
proposes, the passes taken in order, or none where none proposes one. -/
def inPasses (current : Seq) (spans : List Span) (accepted : Bool) (passes : List Pass) : Option Shrinking :=
  match passes with
  | [] => none
  | p :: ps =>
    match firstSmaller current spans p accepted 0 (p.candidates current spans) with
    | some s => some s
    | none => inPasses current spans accepted ps

/-- The passes of `ps` a round takes, having `accepted` a candidate or not: each, less the costly ones where it has. -/
def taken (accepted : Bool) (ps : List Pass) : List Pass := ps.filter fun p => !accepted || !p.costly

/-- The first state from the candidates `cs` of `pass` on, the first at `position`, that proposes a candidate smaller
than `current`, whose run made `spans`, moving through the later passes a round takes and into a new round as each runs
out, or ended where a round ends with nothing `accepted`. -/
def seek (current : Seq) (spans : List Span) (pass : Pass) (position : Nat) (cs : List Seq) (accepted : Bool) :
    Shrink :=
  match firstSmaller current spans pass accepted position cs with
  | some s => .shrinking s
  | none =>
    match inPasses current spans accepted (taken accepted pass.later) with
    | some s => .shrinking s
    | none =>
      if accepted then
        match inPasses current spans false Pass.all with
        | some s => .shrinking s
        | none => .shrunk current
      else .shrunk current

/-- The first state of shrinking `first`, a sequence whose run failed making `spans`. -/
def start (first : Seq) (spans : List Span) : Shrink :=
  seek first spans .deleteLast 0 (Pass.deleteLast.candidates first spans) false

/-- The state after `s`'s candidate's run, told as `answer`, the record a failing run made taking the place of the
current sequence and its pass going on from where `Pass.resumeAt` names. -/
def told (s : Shrinking) (answer : Answer) : Shrink :=
  match answer with
  | .failing read spans =>
    let current := record s.candidate read
    let position := s.pass.resumeAt s.current s.position current
    seek current spans s.pass position ((s.pass.candidates current spans).drop position) true
  | .notFailing => seek s.current s.spans s.pass (s.position + 1) s.rest s.accepted

end Grit
