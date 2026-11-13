import Shrink.Answers
import Shrink.Seeking

/-!
That shrinking ends, proved of the model, and an obviously wrong step function shown to fail it, so it holds not
vacuously.
-/

namespace Grit

/-- Shrinking always ends, whatever the oracle answers: from any first failure and the spans its run made, whatever the
answers, some number of steps reaches a state that has ended. -/
def AlwaysEnds (start : Seq → List Span → Shrink) (told : Shrinking → Answer → Shrink) : Prop :=
  ∀ first spans answers, ∃ n current, after start told first spans answers n = .shrunk current

theorem walk_shrinking {told s answers} : ∀ n,
    walk told (.shrinking s) answers (n + 1) = walk told (told s (answers 0)) (fun k => answers (k + 1)) n
  | 0 => rfl
  | n + 1 => by
    show (match walk told (.shrinking s) answers (n + 1) with
      | .shrinking s => told s (answers (n + 1))
      | .shrunk current => .shrunk current) = _
    rw [walk_shrinking n]
    rfl

/-- How far a state stands from the end of its sequence's rounds: its round's accepting a candidate, the passes left
after its own, and the candidates left in its own. -/
def remaining (s : Shrinking) : Nat × Nat × Nat := (s.accepted.toNat, s.pass.later.length, s.rest.length)

/-- A state's place in the order shrinking descends: its current sequence, then how far it stands from the end of its
rounds. -/
def rank (s : Shrinking) : Seq × Nat × Nat × Nat := (s.current, remaining s)

/-- The order shrinking descends, under which every step from a proper state goes down. -/
def Below : Shrinking → Shrinking → Prop :=
  InvImage (Prod.Lex Smaller (Prod.Lex (· < ·) (Prod.Lex (· < ·) (· < ·)))) rank

theorem below_wf : WellFounded Below :=
  InvImage.wf _
    (Prod.lex ⟨_, smaller_wf⟩ (Prod.lex ⟨_, Nat.lt_wfRel.wf⟩
      (Prod.lex ⟨_, Nat.lt_wfRel.wf⟩ ⟨_, Nat.lt_wfRel.wf⟩))).wf

theorem later_shorter {p q : Pass} (h : q ∈ p.later) : q.later.length < p.later.length := by
  cases p <;> cases q <;> simp [Pass.later] at h ⊢

theorem seek_spec {current spans pass position cs accepted s}
    (h : seek current spans pass position cs accepted = .shrinking s) :
    s.current = current ∧ Proper s ∧
      Prod.Lex (· < ·) (Prod.Lex (· < ·) (· < ·)) (remaining s) (accepted.toNat, pass.later.length, cs.length) := by
  unfold seek at h
  split at h
  · next hf =>
    cases h
    obtain ⟨h1, h2, h3, h4, h5⟩ := firstSmaller_spec hf
    refine ⟨h1, h4, ?_⟩
    simp only [remaining, h2, h3]
    exact .right _ (.right _ h5)
  · split at h
    · next hi =>
      cases h
      obtain ⟨h1, h2, h3, h4⟩ := inPasses_spec hi
      refine ⟨h1, h3, ?_⟩
      simp only [remaining, h2]
      exact .right _ (.left _ _ (later_shorter h4))
    · split at h
      · next ha =>
        split at h
        · next hi =>
          cases h
          obtain ⟨h1, h2, h3, _⟩ := inPasses_spec hi
          refine ⟨h1, h3, ?_⟩
          simp only [remaining, h2, ha]
          exact .left _ _ (by decide)
        · cases h
      · cases h

theorem told_below {s s' : Shrinking} {answer : Answer} (hs : Proper s) (h : told s answer = .shrinking s') :
    Proper s' ∧ Below s' s := by
  cases answer with
  | failing spans =>
    obtain ⟨h1, h2, _⟩ := seek_spec h
    refine ⟨h2, ?_⟩
    simp only [Below, InvImage, rank, h1]
    exact .left _ _ hs
  | notFailing =>
    obtain ⟨h1, h2, h3⟩ := seek_spec h
    refine ⟨h2, ?_⟩
    simp only [Below, InvImage, rank, h1]
    exact .right _ h3

theorem proper_ends : ∀ s, Proper s → ∀ answers, ∃ n current, walk told (.shrinking s) answers n = .shrunk current := by
  intro s
  induction s using below_wf.induction with
  | _ s ih =>
    intro hs answers
    match h : told s (answers 0) with
    | .shrunk current => exact ⟨1, current, h⟩
    | .shrinking s' =>
      obtain ⟨hp, hb⟩ := told_below hs h
      obtain ⟨n, current, hn⟩ := ih s' hb hp (fun k => answers (k + 1))
      exact ⟨n + 1, current, by rw [walk_shrinking, h, hn]⟩

theorem told_always_ends : AlwaysEnds start told := by
  intro first spans answers
  show ∃ n current, walk told (start first spans) answers n = .shrunk current
  match h : start first spans with
  | .shrunk current => exact ⟨0, current, rfl⟩
  | .shrinking s => exact proper_ends s (seek_spec h).2.1 answers

/-- An obviously wrong step function: told its candidate did not fail, it proposes the same candidate again. -/
def toldStays (s : Shrinking) (answer : Answer) : Shrink :=
  match answer with
  | .failing spans => told s (.failing spans)
  | .notFailing => .shrinking s

theorem toldStays_fails : ¬ AlwaysEnds start toldStays := by
  intro h
  obtain ⟨n, current, hn⟩ := h [1] [] (fun _ => .notFailing)
  have stays : ∀ n, ∃ s, after start toldStays [1] [] (fun _ => .notFailing) n = .shrinking s := by
    intro n
    induction n with
    | zero => exact ⟨_, rfl⟩
    | succ n ih =>
      obtain ⟨s, hs⟩ := ih
      exact ⟨s, by rw [after_succ, hs]; rfl⟩
  obtain ⟨s, hs⟩ := stays n
  rw [hs] at hn
  cases hn

end Grit
