---
type: knowledge
aliases: report, reading a failure, shrinking, budget, flaky, gave up, warnings, slow property
---

# Failures

A failing property's report gives its smallest failing case: what the body drew, what it noted and what it threw, how shrinking ended, and how to run the case again. This page reads a report part by part, then says how shrinking reaches its case, and what the other outcomes mean.

## Reading a report

A midpoint that adds its bounds overflows once they are large:

```dart
int midpoint(int low, int high) => (low + high) ~/ 2;

property('a midpoint lies between its bounds', (draw) {
  final int low = draw(.integer(min: 0, max: Choice.largest.value), label: 'low');
  final int high = draw(.integer(min: low, max: Choice.largest.value), label: 'high');
  final int middle = midpoint(low, high);
  draw.note('midpoint $middle');
  expect(middle, inInclusiveRange(low, high));
});
```

```text
The property failed. Its smallest failing case, shrunk in 378 steps over 21 ms:

It drew:
  low: 4611686018427387904
  high: 4611686018427387904

It noted:
  midpoint -4611686018427387904

It threw:
  Expected: be in range from 4611686018427387904 (inclusive) to 4611686018427387904 (inclusive)
    Actual: <-4611686018427387904>

Replay this case alone with `settings: Settings(replay: 'grit1:z1ci99jj7474.0')`.

Seed 1185975699. The next search at this call site replays this failure first, so `settings: Settings(seed: 1185975699)` repeats this search once `.dart_tool/grit/` no longer holds it.
```

Its parts, in order:

- Shrinking: how many steps it took and how long, or which of the budget's bounds ran out first, in which case the case is the smallest found within the budget.
- Draws: each value the body drew, under its label ([drawing.md](drawing.md)). Here both are 2⁶², so their sum is one past the largest `int`.
- Notes: each line the body noted, where it noted any.
- Error: what the body threw, and below the report, the stack trace of the case's last run, pointing at the line of the body that threw.
- Store: a line saying the failure was first found by replaying the failure an earlier search stored, where it was.
- Token: the setting that replays this one case alone ([replay.md](replay.md)).
- Seed: the setting that repeats the whole search, once the stored failure is gone.

A report carries the search's warnings, one per paragraph, before its last lines.

## Shrinking

Shrinking works on the record of the random choices a run made, never on the value. Every generator, a built one among them, shrinks with no shrinking code of its own, and a value made of parts shrinks whole: an element dropped from a list takes every choice inside it, and a value drawn after it is drawn again from its own choices. Smaller here means fewer choices, then smaller ones, and every generator puts its simplest values at its smallest choices.

A smaller case counts only where it fails as the first failure did: the same type of error, thrown from the same line of the property's package. A case that fails any other way is passed over, so shrinking never slips from one bug to another.

Shrinking always ends, and runs within a budget of steps and of wall time, with defaults no property has to change ([settings.md](settings.md)). A step is one run of a smaller case. A spent budget ends shrinking on the smallest failure found so far, and the report says which bound ran out:

```text
The property failed. Shrinking ran out of steps after 20 steps, over 977 µs, so its failing case is the smallest found within the budget:
```

grit runs the case once more after shrinking, to confirm it still fails, so every case a report gives fails.

## Flaky

A property is flaky where its failing case does not fail the same way when it runs again:

```text
The property is flaky: it failed, then did not fail the same way when its failing case ran again.

It drew:
  x: 27

It threw:
  Bad state: the third call

Run again, it returned.
```

Its body turns on something other than what it drew: the time, a `Random` of its own, or state that one run leaves for the next, such as a counter or a list outside the body. A body that draws all its randomness and sets up its own state on every run is never flaky.

## Gave up

A search gives up where too many runs are rejected or overrun before the run count returns: ten for each run the settings ask for.

```text
The property gave up: 1000 runs were rejected and 0 overran before enough returned. A run is rejected by an assume that is false, a filter that finds no value or a set that finds too few distinct elements, and overruns where it makes more choices than one run may.
```

A run is rejected by an `assume` that is false, a `filter` that finds no value or a `set` short of distinct elements ([generators.md](generators.md)). It overruns where it makes more than 8192 choices, such as a list of long lists of long strings. A generator that draws only valid values, and smaller collections, fix either.

## Warnings

A warning never changes a verdict. A passing property that warns prints its report under its test, and a failing one's report carries it.

- Slow property: its runs cost more than five seconds at their mean time per run, so a lower `runs` setting makes it faster.
- Mostly invalid runs: more runs were rejected or overran than returned, in a search that did not give up.
- Unreadable stored failure: the file the store held for the call site was no token grit reads, so the search deleted it and generated afresh.
