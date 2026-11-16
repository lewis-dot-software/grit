---
type: knowledge
aliases: runs, seed, shrinkSteps, shrinkTime, replay, configuration, budget
---

# Settings

A property's `Settings` say how it is searched, each with a default no property has to change. `property`, `forAll` and `runProperty` each take them as `settings`:

```dart
property('a sort keeps every element', (draw) {
  final List<int> xs = draw(.list(.integer()), label: 'xs');
  expect(xs.toList()..sort(), unorderedEquals(xs));
}, settings: Settings(runs: 1000));
```

| Setting | Default | Is |
|---|---|---|
| `runs` | 100 | How many runs must return for the property to pass |
| `seed` | Drawn per search | The seed the search's random choices are filled from |
| `shrinkSteps` | 5000 | The most smaller cases shrinking runs |
| `shrinkTime` | 10 seconds | The longest shrinking may take |
| `replay` | None | A failing case's token, replayed alone in place of a search |

`runs` counts the runs that return: a rejected run is run again in its place, until a search with too many gives up ([failures.md](failures.md)). A higher count searches further and takes longer, and a slow search warns of it.

`shrinkSteps` and `shrinkTime` are shrinking's budget: whichever runs out first ends shrinking on the smallest failure found so far, and the report says so. Neither bounds generation, and no setting bounds a property's time, since no deadline of grit's fails a property. A `shrinkSteps` of 0 reports the first failure found, unshrunk.

`seed` and `replay` are for running a failure again ([replay.md](replay.md)). Each is printed in a failure's report as the setting to paste.

A `runs` below 1, or a negative `shrinkSteps` or `shrinkTime`, throws a `RangeError` naming it, and a `replay` that is no token throws an `ArgumentError`, each as the settings are made. Settings shared by several properties are a top-level `final`:

```dart
final Settings thorough = .new(runs: 1000, shrinkTime: const .new(minutes: 1));
```
