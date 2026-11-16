---
type: knowledge
aliases: glados, migrating from glados, Glados, any, ExploreConfig
---

# Coming from glados

glados hands a property its inputs as arguments, from generators chosen up front, and grit's body draws them as it needs them. Most of a move from glados is that one change: each argument becomes a draw.

```dart
// glados
Glados2(any.list(any.int), any.int).test('a list holds what is added', (xs, x) {
  expect([...xs, x], contains(x));
});

// grit
property('a list holds what is added', (draw) {
  final List<int> xs = draw(.list(.integer()), label: 'xs');
  final int x = draw(.integer(), label: 'x');
  expect([...xs, x], contains(x));
});
```

No `Glados2` or `Glados3` is needed for two or three inputs, and an input can depend on one drawn before it ([drawing.md](drawing.md)).

## Declaring

| glados | grit |
|---|---|
| `Glados(gen).test(name, (x) {...})` | `property(name, (draw) {...})`, drawing `x` |
| `Glados2` and `Glados3` | One draw per input |
| `Glados<T>()`, a type's default generator | The generator named in the draw |
| `testWithRandom`, handed a `Random` | A draw for each random value |
| `test`'s `timeout` | None: a property has no timeout |
| A search inside a `testWidgets` | `forAll` ([properties.md](properties.md)) |

## Generators

glados's `any` holds its generators, and grit's are `Gen`'s static members, named by dot shorthand inside a draw ([generators.md](generators.md)). glados takes a range's maximum as exclusive, and grit takes every bound as inclusive. grit's `.float()` draws NaN and the infinities unless told not to, and glados's doubles are always finite.

| glados | grit |
|---|---|
| `any.int` | `.integer()` |
| `any.intInRange(min, max)` | `.integer(min: min, max: max - 1)` |
| `any.positiveInt`, `any.positiveIntOrZero` | `.integer(min: 1)`, `.integer(min: 0)` |
| `any.double` | `.float(nan: false, infinite: false)` |
| `any.doubleInRange(min, max)` | `.float(min: min, max: max, nan: false, infinite: false)` |
| `any.bool` | `.boolean()` |
| `any.list(gen)`, `any.nonEmptyList(gen)` | `.list(gen)`, `.list(gen, minLength: 1)` |
| `any.listWithLengthInRange(min, max, gen)` | `.list(gen, minLength: min, maxLength: max - 1)` |
| `any.set(gen)` | `.set(gen)` |
| `any.letters`, `any.lowercaseLetters`, `any.digits` | `.string(alphabet: .letters)`, `.lowerCase`, `.digits` |
| `any.letterOrDigits` | `.string(alphabet: .lettersAndDigits)` |
| `any.stringOf(chars)` | `.string(alphabet: .of(chars))` |
| `any.choose(values)` | `.element(values)` |
| `any.oneOf(gens)`, `any.either(a, b)` | `.oneOf(gens)`, `.oneOf([a, b])` |
| `any.combine2(a, b, combine)` | `Gen.build((draw) => combine(draw(a), draw(b)))` |
| `gen.map(convert)` | `gen.map(convert)` |
| `gen.bind(next)` | A draw of `next`'s generator on the value drawn before it |

A generator of glados's that grit lacks is built in a line from those it has:

```dart
final Gen<Duration> duration = Gen.integer(min: 0).map((ms) => Duration(milliseconds: ms));
final Gen<DateTime> instant = Gen.integer(min: 0, max: 1 << 40).map(DateTime.fromMillisecondsSinceEpoch);
final Gen<int?> maybe = Gen.oneOf([Gen.element([null]), Gen.integer()]);
```

An `extension` on `Any` that adds a generator becomes a top-level `final` `Gen`, drawn by its name.

## Generators of one's own

A glados generator of its own is a `generate` and a `shrink` function, or a `combine` of others, and its shrinking is only as good as the `shrink` written for it. grit shrinks the random choices a value was made from, so a generator built with `Gen.build` shrinks with no shrinking code, and a structured value shrinks whole.

## Settings

| glados | grit |
|---|---|
| `ExploreConfig(numRuns: n)` | `Settings(runs: n)` |
| `ExploreConfig(random: Random(s))` | `Settings(seed: s)` |
| `initialSize` and `speed` | None: a generator's bounds set its range |

glados fills from `Random(42)` by default, so every run of the suite searches the same inputs. grit draws a seed afresh for each search, so every run of the suite searches further, and a failure's report prints its seed and its token to run it again ([replay.md](replay.md)).

## Failures

glados's shrinking has no bound on its steps or its time. grit's shrinking runs within a budget of steps and of wall time, and a spent budget reports the smallest failure found so far ([failures.md](failures.md)). grit also keeps each property's failure and replays it first on the next run, and counts a smaller case only where it fails as the first did, so a case never slips from one bug to another while it shrinks.
