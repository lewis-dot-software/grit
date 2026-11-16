---
type: knowledge
aliases: Passed, Failed, Flaky, GaveUp, Reproduced, NotReproduced, Run, Threw, Warning, ChoiceSequence, runProperty result
---

# Outcomes

A search comes to one `Outcome`, a sealed type with a case per way it can end. `property` and `forAll` turn it into a test's verdict and report ([failures.md](failures.md)), and `runProperty` returns it ([properties.md](properties.md)), so a tool or a test reads it by a `switch` that names every case:

```dart
final Outcome outcome = await runProperty(body);
final String verdict = switch (outcome) {
  Passed(:final int runs) => 'passed $runs runs',
  Failed(:final Threw run) => 'failed on ${run.draws.map((drawn) => drawn.text)}',
  Flaky() => 'flaky',
  GaveUp(:final int rejected) => 'gave up after $rejected rejected',
  Reproduced() || NotReproduced() => 'replayed its token',
};
```

Every outcome carries `warnings`, the list of `Warning`s the search raised, none of which changed its verdict.

## Searches

`Passed` holds `runs`, how many runs returned.

`Failed` is a property that failed, and whose smallest failing case failed again on its last run:

- `sequence`: the smallest failing case, as the `ChoiceSequence` its run made.
- `run`: the case's last run, a `Threw` with its error and its draws.
- `firstFound`: where the failure shrinking started from was found, a `FirstFound`, `generated` by a random run or `stored` by the store's replay.
- `steps`: how many smaller cases shrinking ran.
- `time`: how long shrinking took.
- `end`: what ended shrinking, a `ShrinkEnd`: `shrunk` where it ran out of smaller cases, or `steps` or `time` where that bound of the budget ran out.

`Flaky` is a property whose failing case did not fail the same way when it ran again:

- `failed`: the run that failed, a `Threw`.
- `firstFound`: where that failure was found.
- `replay`: the run of the same case that did not fail as it did.

`GaveUp` is a search with too many invalid runs: `rejected` counts the runs rejected, and `overran` those that made more choices than one run may.

## Token replays

A property whose settings name a `replay` token comes to one of two outcomes ([replay.md](replay.md)):

- `Reproduced`: the token's `run` threw, a `Threw`.
- `NotReproduced`: the token's `run` returned, was rejected or overran.

## Runs

A `Run` is one run of the body, by how it ended:

- `Returned`: the body returned.
- `Rejected`: an `assume`, a `filter` or a `set` rejected it.
- `Overran`: it made more choices than its source held.
- `Threw`: the body threw.

Every run holds its `record`, the `ChoiceSequence` of the choices it made, its `draws`, each value drawn as a `Drawn` ([drawing.md](drawing.md)), and its `notes`, each line noted.

A `Threw` holds the `error` the body threw, its `stackTrace`, and its `failure`, a `Failure` record of the error's `type` and the `frame` it was thrown from, null where its stack held none grit reads. `failedAlike(run)` says whether another run failed as it did: an error of the same type from the same frame, or a stack overflow from any frame, since an overflow strikes wherever the stack runs out.

A `Frame` is one frame of a stack: the library's `uri`, the `line`, and the `package` that library lies in, the scheme alone where it lies in none. `Frame.of(stackTrace)` reads a stack's frames, innermost first, in the Dart VM's form.

## Choices

A `ChoiceSequence` is a run's record: its `choices`, in the order the run made them, each a `Choice`. A choice's `value` is a natural number from 0, the simplest, to `Choice.largest`, the largest the Dart VM's integers hold. Sequences order shortlex: one `isSmallerThan` another where it is shorter, or the same length and smaller at its first difference, and `compareTo` orders them so.

## Warnings

A `Warning` is one of three cases:

- `SlowProperty`: the search's runs took `perRun` each on average, slow enough at its `runs` to warn of ([failures.md](failures.md)).
- `MostlyInvalid`: more runs were rejected or overran than returned, counted as `returned`, `rejected` and `overran`.
- `UnreadableStored`: the store held text for the call site that decodes to no sequence, for the `reason`, an `Undecodable` ([replay.md](replay.md)).
