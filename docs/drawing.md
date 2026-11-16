---
type: knowledge
aliases: draw, Draw, labels, assume, note, dependent inputs, Drawn
---

# Drawing inputs

A property's body draws each input as it needs it, by calling its `Draw` on a generator. No arity is chosen up front, a draw can depend on the values drawn before it, and a failure's report lists every value drawn, in order.

## A draw

`draw(gen)`, which is `Draw.call`, returns a value of the generator's type. Inside the call a generator is named by dot shorthand, since the draw expects a `Gen` ([generators.md](generators.md)):

```dart
property('a slice of a list is no longer than the list', (draw) {
  final List<int> xs = draw(.list(.integer(), minLength: 1), label: 'xs');
  final int start = draw(.integer(min: 0, max: xs.length - 1), label: 'start');
  final int end = draw(.integer(min: start, max: xs.length), label: 'end');
  expect(xs.sublist(start, end).length, lessThanOrEqualTo(xs.length));
});
```

`start` and `end` depend on what was drawn before them, and they stay valid as the case shrinks. A draw is a record of the random choices it made, and shrinking works on that record, never on the value. Once shrinking cuts `xs` shorter, the run that tries the shorter list draws `start` and `end` again, from their own choices, within the new bounds.

A body may draw inside a loop or a branch, after an `await`, and as many times as it needs. The one rule is that a run draws the same way whenever its choices are the same: a body whose draws turn on anything else, such as the time or a value left over from an earlier run, cannot be replayed, and its failure comes out flaky ([failures.md](failures.md)).

## Labels

A draw's `label` names its value in a failure's report:

```text
It drew:
  xs: [0, 0, 0]
  start: 0
  end: 3
```

A draw with no label prints its value bare. Each value is a `Drawn`, a record of its `label`, its `value` and its `text`, the value's text as the draw returned it, so a list the body sorts in place prints as it was drawn. A string prints as a Dart literal, so its whitespace and control characters show, and so does each string inside a list, a set or a map. Any other value prints its own `toString`.

The report lists the draws the body made itself. A draw inside a generator built with `Gen.build` is part of the value it builds, so the built value is what prints.

## Assumptions

`draw.assume(condition)` rejects the run where its condition is false. A rejected run neither passes nor fails, and grit runs another in its place:

```dart
property('a quotient times its divisor stays within the dividend', (draw) {
  final int a = draw(.integer(), label: 'a');
  final int b = draw(.integer(), label: 'b');
  draw.assume(b != 0);
  expect((a ~/ b * b).abs(), lessThanOrEqualTo(a.abs()));
});
```

An assumption suits a condition that rarely fails, as `b != 0` does. Where most runs would be rejected, a generator that draws only valid values is faster and finds more, such as `.integer(min: 1)` for a positive divisor. A search whose runs are mostly rejected warns of it, and one with too many gives up ([failures.md](failures.md)).

## Notes

`draw.note(line)` adds a line to the report of a run that fails, under `It noted`, for a value worked out from the draws:

```dart
final int middle = midpoint(low, high);
draw.note('midpoint $middle');
```

A run that passes prints none of its notes.
