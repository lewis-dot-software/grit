import Shrink.Answers
import Shrink.Seeking

/-!
What shrinking holds as its current sequence, proved of the model, and an obviously wrong step function shown to fail
it, so it holds not vacuously.
-/

namespace Grit

/-- The current sequence is always the record the first failure's run read, or one a candidate's run read when told it
failed: after any number of steps from any first failure and the spans its run made, whatever the answers, the current
sequence is `first`, or the record of the candidate of some earlier step that was answered as failing, as many of its
choices as that answer says the run read. -/
def HoldsOnlyFailures (start : Seq → List Span → Shrink) (told : Shrinking → Answer → Shrink) : Prop :=
  ∀ first spans answers n,
    (after start told first spans answers n).current = first ∨
    ∃ k < n, ∃ read made, answers k = .failing read made ∧
      ∃ s, after start told first spans answers k = .shrinking s ∧
        record s.candidate read = (after start told first spans answers n).current

theorem start_current {first spans} : (start first spans).current = first := seek_current

theorem told_failing_current {s : Shrinking} {read spans} :
    (told s (.failing read spans)).current = record s.candidate read :=
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
        rcases ih with ih | ⟨k, hk, read, made, hak, t, ht, hc⟩
        · exact .inl ih
        · exact .inr ⟨k, by omega, read, made, hak, t, ht, by rw [hc]; rfl⟩
      | failing read made =>
        rw [told_failing_current]
        exact .inr ⟨n, by omega, read, made, ha, s, h, rfl⟩
    · next current h =>
      rw [h] at ih
      rcases ih with ih | ⟨k, hk, read, made, hak, t, ht, hc⟩
      · exact .inl ih
      · exact .inr ⟨k, by omega, read, made, hak, t, ht, hc⟩

/-- An obviously wrong step function: it takes every candidate as the current sequence, whatever it is told. -/
def toldTakesEvery (s : Shrinking) (_answer : Answer) : Shrink := told s (.failing s.candidate.length s.spans)

theorem toldTakesEvery_fails : ¬ HoldsOnlyFailures start toldTakesEvery := by
  intro h
  rcases h [1] [] (fun _ => .notFailing) 1 with h | ⟨k, hk, read, made, hak, _⟩
  · revert h
    decide
  · cases hak

/-- A wrong step function: told a candidate failed, it takes the whole candidate as the current sequence, though its run
read fewer of its choices. -/
def toldKeepsCandidate (s : Shrinking) (answer : Answer) : Shrink :=
  match answer with
  | .failing _ spans => told s (.failing s.candidate.length spans)
  | .notFailing => told s .notFailing

theorem toldKeepsCandidate_fails : ¬ HoldsOnlyFailures start toldKeepsCandidate := by
  intro h
  rcases h [0, 0, 0, 0, 0] [] (fun _ => .failing 0 []) 1 with h | ⟨k, hk, read, made, hak, s, _, hc⟩
  · revert h
    decide
  · obtain ⟨rfl, rfl⟩ := Answer.failing.inj hak
    rw [show record s.candidate 0 = [] from List.take_zero] at hc
    revert hc
    decide

end Grit
