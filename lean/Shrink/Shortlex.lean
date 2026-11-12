import Shrink.Sequence

/-!
Shortlex has no endless descent: every chain of sequences each smaller than the one before it ends.
-/

namespace Grit

/-- `a` is smaller than `b` at their first difference, and alike in length. -/
def LexSame (a b : Seq) : Prop := a.length = b.length ∧ lexLess a b = true

/-- `a` is shortlex smaller than `b`. -/
def Smaller (a b : Seq) : Prop := smaller a b = true

theorem lexSame_nil {a : Seq} : ¬ LexSame a [] := by
  intro ⟨_, h⟩
  cases a <;> simp [lexLess] at h

theorem lexSame_cons {y x : Nat} {ys xs : Seq} (h : LexSame (y :: ys) (x :: xs)) :
    y < x ∨ (y = x ∧ LexSame ys xs) := by
  obtain ⟨hl, h⟩ := h
  simp only [lexLess, Bool.or_eq_true, decide_eq_true_eq, Bool.and_eq_true, beq_iff_eq] at h
  rcases h with h | ⟨rfl, h⟩
  · exact .inl h
  · exact .inr ⟨rfl, by simpa using hl, h⟩

theorem lexSame_acc_cons (n : Nat) (ih : ∀ l : Seq, l.length = n → Acc LexSame l) :
    ∀ x (xs : Seq), xs.length = n → Acc LexSame (x :: xs) := by
  intro x
  induction x using Nat.strongRecOn with
  | ind x hx =>
    intro xs hxs
    have hacc := ih xs hxs
    clear ih
    induction hacc with
    | intro xs _ ihxs =>
      refine ⟨_, fun b hb => ?_⟩
      match b, hb with
      | [], hb => exact absurd hb.1 (by simp)
      | y :: ys, hb =>
        have hys : ys.length = n := by
          have := hb.1
          simp only [List.length_cons, Nat.add_right_cancel_iff] at this
          omega
        rcases lexSame_cons hb with hlt | ⟨rfl, hl⟩
        · exact hx y hlt ys hys
        · exact ihxs ys hl hys

theorem lexSame_acc : ∀ n (l : Seq), l.length = n → Acc LexSame l
  | 0, l, h => by
    rw [List.length_eq_zero_iff] at h
    subst h
    exact ⟨_, fun _ ha => absurd ha lexSame_nil⟩
  | n + 1, x :: xs, h => lexSame_acc_cons n (lexSame_acc n) x xs (by simpa using h)

theorem lexSame_wf : WellFounded LexSame := ⟨fun l => lexSame_acc l.length l rfl⟩

theorem smaller_cases {a b : Seq} (h : Smaller a b) :
    a.length < b.length ∨ (a.length = b.length ∧ LexSame a b) := by
  unfold Smaller smaller at h
  split at h
  · next he => exact .inr ⟨he, he, h⟩
  · exact .inl (by simpa using h)

theorem smaller_wf : WellFounded Smaller :=
  Subrelation.wf
    (r := InvImage (Prod.Lex (· < ·) LexSame) fun l : Seq => (l.length, l))
    (fun h => by
      rcases smaller_cases h with h | ⟨he, h⟩
      · exact Prod.Lex.left _ _ h
      · simp only [InvImage, he]
        exact Prod.Lex.right _ h)
    (InvImage.wf _ (Prod.lex ⟨_, Nat.lt_wfRel.wf⟩ ⟨_, lexSame_wf⟩).wf)

end Grit
