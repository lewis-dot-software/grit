import Shrink.Answers
import Shrink.Seeking

/-!
What shrinking holds as its current sequence, proved of the model, and an obviously wrong step function shown to fail
it, so it holds not vacuously.
-/

namespace Grit

/-- The current sequence is always the first failure or one the oracle said failed: after any number of steps from any
first failure and the spans its run made, whatever the answers, the current sequence is `first`, or the candidate of
some earlier step that was answered as failing. -/
def HoldsOnlyFailures (start : Seq → List Span → Shrink) (told : Shrinking → Answer → Shrink) : Prop :=
  ∀ first spans answers n,
    (after start told first spans answers n).current = first ∨
    ∃ k < n, (∃ made, answers k = .failing made) ∧
      ∃ s, after start told first spans answers k = .shrinking s ∧
        s.candidate = (after start told first spans answers n).current

theorem start_current {first spans} : (start first spans).current = first := seek_current

theorem told_failing_current {s : Shrinking} {spans} : (told s (.failing spans)).current = s.candidate :=
  seek_current

theorem told_notFailing_current {s : Shrinking} : (told s .notFailing).current = s.current := seek_current

theorem told_holds_only_failures : HoldsOnlyFailures start told := by
  intro first spans answers n
  induction n with
  | zero => exact .inl start_current
  | succ n ih =>
    rw [after_succ]
    split
    · next s h =>
      rw [h] at ih
      cases ha : answers n with
      | notFailing =>
        rw [told_notFailing_current]
        rcases ih with ih | ⟨k, hk, hak, t, ht, hc⟩
        · exact .inl ih
        · exact .inr ⟨k, by omega, hak, t, ht, by rw [hc]; rfl⟩
      | failing made =>
        rw [told_failing_current]
        exact .inr ⟨n, by omega, ⟨made, ha⟩, s, h, rfl⟩
    · next current h =>
      rw [h] at ih
      rcases ih with ih | ⟨k, hk, hak, t, ht, hc⟩
      · exact .inl ih
      · exact .inr ⟨k, by omega, hak, t, ht, hc⟩

/-- An obviously wrong step function: it takes every candidate as the current sequence, whatever it is told. -/
def toldTakesEvery (s : Shrinking) (_answer : Answer) : Shrink := told s (.failing s.spans)

theorem toldTakesEvery_fails : ¬ HoldsOnlyFailures start toldTakesEvery := by
  intro h
  rcases h [1] [] (fun _ => .notFailing) 1 with h | ⟨k, hk, ⟨made, hak⟩, _⟩
  · revert h
    decide
  · cases hak

end Grit
