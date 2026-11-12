import Shrink.Answers

/-!
What shrinking holds as its current sequence, proved of the model, and an obviously wrong step function shown to fail
it, so it holds not vacuously.
-/

namespace Grit

/-- The current sequence is always the first failure or one the oracle said failed: after any number of steps, whatever
the answers, the current sequence is `first`, or the candidate of some earlier step that was answered as failing. -/
def HoldsOnlyFailures (start : Seq → Shrink) (told : Shrinking → Bool → Shrink) : Prop :=
  ∀ first answers n,
    (after start told first answers n).current = first ∨
    ∃ k < n, answers k = true ∧
      ∃ s, after start told first answers k = .shrinking s ∧ s.candidate = (after start told first answers n).current

theorem firstSmaller_current {current : Seq} {pass : Pass} {accepted : Bool} :
    ∀ {position cs s}, firstSmaller current pass accepted position cs = some s → s.current = current
  | _, [], _, h => by simp [firstSmaller] at h
  | position, c :: cs, s, h => by
    unfold firstSmaller at h
    split at h
    · cases h; rfl
    · exact firstSmaller_current h

theorem inPasses_current {current : Seq} {accepted : Bool} :
    ∀ {passes s}, inPasses current accepted passes = some s → s.current = current
  | [], _, h => by simp [inPasses] at h
  | p :: ps, s, h => by
    unfold inPasses at h
    split at h
    · cases h; exact firstSmaller_current (by assumption)
    · exact inPasses_current h

theorem seek_current {current pass position cs accepted} :
    (seek current pass position cs accepted).current = current := by
  unfold seek
  split
  · exact firstSmaller_current (by assumption)
  · split
    · exact inPasses_current (by assumption)
    · split
      · split
        · exact inPasses_current (by assumption)
        · rfl
      · rfl

theorem start_current {first} : (start first).current = first := seek_current

theorem told_current {s : Shrinking} {failed : Bool} :
    (told s failed).current = if failed then s.candidate else s.current := by
  unfold told
  cases failed <;> exact seek_current

theorem told_holds_only_failures : HoldsOnlyFailures start told := by
  intro first answers n
  induction n with
  | zero => exact .inl start_current
  | succ n ih =>
    simp only [after]
    split
    · next s h =>
      rw [h] at ih
      cases ha : answers n
      · simp only [told_current, Bool.false_eq_true, ↓reduceIte]
        rcases ih with ih | ⟨k, hk, hak, t, ht, hc⟩
        · exact .inl ih
        · exact .inr ⟨k, by omega, hak, t, ht, by rw [hc]; rfl⟩
      · simp only [told_current, ↓reduceIte]
        exact .inr ⟨n, by omega, ha, s, h, rfl⟩
    · next current h =>
      rw [h] at ih
      rcases ih with ih | ⟨k, hk, hak, t, ht, hc⟩
      · exact .inl ih
      · exact .inr ⟨k, by omega, hak, t, ht, hc⟩

/-- An obviously wrong step function: it takes every candidate as the current sequence, whatever it is told. -/
def toldTakesEvery (s : Shrinking) (_failed : Bool) : Shrink := told s true

theorem toldTakesEvery_fails : ¬ HoldsOnlyFailures start toldTakesEvery := by
  intro h
  rcases h [1] (fun _ => false) 1 with h | ⟨k, hk, hak, _⟩
  · revert h
    decide
  · simp at hak

end Grit
