import Shrink
import Lean

/-!
Every declaration of the Shrink modules rests on Lean's standard axioms alone: no `sorry`, no axiom added, and no
proof trusted to compiled code. The build fails naming each declaration that rests on anything else.
-/

open Lean Elab Command

/-- The axioms Lean's own library rests on. -/
def standardAxioms : List Name := [``propext, ``Classical.choice, ``Quot.sound]

/-- Fails naming each declaration of the Shrink modules that rests on an axiom beyond the standard three. -/
elab "#audit_shrink_axioms" : command => do
  let env ← getEnv
  let mut offences : Array MessageData := #[]
  let mut audited := 0
  for (name, _) in env.constants.map₁.toList do
    let some idx := env.getModuleIdxFor? name | continue
    unless (env.header.moduleNames[idx.toNat]!).getRoot == `Shrink do continue
    audited := audited + 1
    let axioms ← liftCoreM <| collectAxioms name
    let beyond := axioms.filter (· ∉ standardAxioms)
    unless beyond.isEmpty do
      offences := offences.push m!"{name} rests on {beyond.toList}"
  if audited == 0 then throwError "no declaration of the Shrink modules was found to audit"
  unless offences.isEmpty do throwError MessageData.joinSep offences.toList "\n"

#audit_shrink_axioms
