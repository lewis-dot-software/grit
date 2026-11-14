---
type: knowledge
aliases: shrinker proofs, Lean model, step function proofs, shrink-model, the shrinker's statements
---

# Shrinker proofs

The shrinker's step function is tested against a model of it written in Lean, and the properties Dan ruled on are proved of that model, by the office's proofs method (`standard/proofs.md` in the office).

| Part | Where |
|---|---|
| Lean model | `lean/Shrink/Sequence.lean`, `Pass.lean` and `Step.lean` |
| Statements and their proofs | `Answers.lean`, `Shortlex.lean`, `Seeking.lean`, `Ending.lean` and `Failing.lean` beside them |
| Axiom audit | `lean/Audit.lean` |
| Model's executable | `lean/Main.lean`, built as `shrink-model` |
| Model test | `test/shrink/shrink_model_test.dart`, thousands of generated first failures and oracles, each path compared candidate by candidate, tagged `lean` |

`dart test` builds `lean/` and runs the model test, failing where elan is missing and naming the line that installs it. `dart test -x lean` runs the rest of the suite without elan, the proofs unchecked.

## What is proved

| Statement | Lean | Wrong implementation it rules out |
|---|---|---|
| Shrinking always ends, whatever the oracle answers | `AlwaysEnds` | Proposing the same candidate again once told it passed |
| The current sequence is always the first failure or one the oracle said failed | `HoldsOnlyFailures` | Taking every candidate as the current sequence, whatever it is told |

Both hold over the record with spans: a first failure comes with the spans its run made, and each answer of failing with the spans the candidate's run made. An oracle is any stream of answers, one a step, so an oracle that answers one candidate two ways, by the step it is asked at, or with spans that fit no run, is among them.

Shrinking ends because each candidate the step function proposes is shortlex smaller than its current sequence, and shortlex has no endless descent, though a choice is any natural number. Between two accepted candidates, the step function passes on through its pass's candidates, then the later passes its round takes, then one round more, so it runs out of rejections too.

## What is not proved

Beyond what no core's proof covers:

- Which candidates each pass proposes. The proofs hold of any candidates, and the model test alone holds the model's passes to the Dart's.
- The spans a run records. The proofs hold of any spans, and the tests on `Draw` and the swap pass alone hold a run's to its draws.
- Shrink quality: how small the end is. The shrinking challenge bench holds that.
- The executable's `replay`, which the model test asks, against `after`, the run the statements speak of. Both step `start` and `told` alike, by reading alone.
- The engine around the step function: the budget, the replays, and what counts as the same failure.
