import Shrink.Step
import Shrink.Shortlex

/-!
What the states `firstSmaller` and `inPasses` reach hold, the current sequence they were given and a candidate shortlex
smaller than it, and that `seek` keeps the current sequence it was given.
-/

namespace Grit

/-- A state's candidate is shortlex smaller than its current sequence. -/
def Proper (s : Shrinking) : Prop := Smaller s.candidate s.current

theorem firstSmaller_spec {current spans pass accepted} : ∀ {position cs s},
    firstSmaller current spans pass accepted position cs = some s →
      s.current = current ∧ s.pass = pass ∧ s.accepted = accepted ∧ Proper s ∧ s.rest.length < cs.length
  | _, [], _, h => by simp [firstSmaller] at h
  | position, c :: cs, s, h => by
    unfold firstSmaller at h
    split at h
    · next hc =>
      cases h
      exact ⟨rfl, rfl, rfl, hc, by simp⟩
    · obtain ⟨h1, h2, h3, h4, h5⟩ := firstSmaller_spec h
      exact ⟨h1, h2, h3, h4, by simp; omega⟩

theorem inPasses_spec {current spans accepted} : ∀ {passes s},
    inPasses current spans accepted passes = some s →
      s.current = current ∧ s.accepted = accepted ∧ Proper s ∧ s.pass ∈ passes
  | [], _, h => by simp [inPasses] at h
  | p :: ps, s, h => by
    unfold inPasses at h
    split at h
    · next hp =>
      cases h
      obtain ⟨h1, h2, h3, h4, _⟩ := firstSmaller_spec hp
      exact ⟨h1, h3, h4, by simp [h2]⟩
    · obtain ⟨h1, h2, h3, h4⟩ := inPasses_spec h
      exact ⟨h1, h2, h3, List.mem_cons_of_mem _ h4⟩

theorem seek_current {current spans pass position cs accepted} :
    (seek current spans pass position cs accepted).current = current := by
  unfold seek
  split
  · exact (firstSmaller_spec (by assumption)).1
  · split
    · exact (inPasses_spec (by assumption)).1
    · split
      · split
        · exact (inPasses_spec (by assumption)).1
        · rfl
      · rfl

end Grit
