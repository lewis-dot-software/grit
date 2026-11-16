---
type: knowledge
aliases: Gen, integer, float, boolean, string, list, set, element, oneOf, Alphabet, build, map, filter, custom generator
---

# Generators

A generator is a `Gen<T>`: it makes a value of `T` from a run's random choices, and the value shrinks as those choices do. Every generator has a simplest value, which shrinking moves towards. grit's generators are `Gen`'s static members, named by dot shorthand wherever a `Gen` is expected, such as inside a draw, and by `Gen.` anywhere else.

| Generator | Draws | Simplest |
|---|---|---|
| `.integer(min:, max:)` | An `int` in range, 32-bit signed by default | The value nearest 0 |
| `.float(min:, max:, nan:, infinite:)` | A `double` in range | The simplest in range, 0.0 by default |
| `.boolean()` | A `bool` | `false` |
| `.string(alphabet:, minLength:, maxLength:)` | A `String` over an `Alphabet` | `minLength` of its first character |
| `.list(element, minLength:, maxLength:)` | A `List` of `element`'s values | `minLength` of `element`'s simplest |
| `.set(element, minSize:, maxSize:)` | A `Set` of `element`'s values | Empty, where `minSize` is 0 |
| `.element(values)` | One of `values` | The first |
| `.oneOf(generators)` | A value of one of `generators` | The first's simplest |

Every bound is inclusive. A range or a length a generator cannot draw from, such as a `min` above its `max`, throws an `ArgumentError` saying why, as the generator is made.

## Numbers

`.integer()` draws from `min` to `max`, each inclusive, by default those of a 32-bit signed integer. It shrinks towards the value in range nearest 0, so a failure for every value above 10 shrinks to 11. `max` lies at most `Choice.largest` above `min`.

`.float()` draws a `double` from `min` to `max`. By default the range is every double, the infinities among them, with NaN drawn as well, and `nan` and `infinite` turn those off or on. A range from `0.0` holds no `-0.0`, since bounds order `-0.0` below `0.0`. Of two doubles, the simpler is the positive before the negative, a whole number before a fraction, and the smaller in magnitude, with the infinities and NaN after every finite double. A double that fails once its magnitude is large enough shrinks to the smallest whole number in range that fails.

The early runs of a search lean towards each choice's edges, such as 0 and a range's bounds, so the cases a bug most often hides in come up whatever the seed.

## Strings

`.string()` draws a string of an alphabet's characters, `minLength` to `maxLength` long, counted in code points, never UTF-16 code units. An `Alphabet` orders its characters simplest first, and a string shrinks as a list of them does: shorter, then towards the first character.

| Alphabet | Holds |
|---|---|
| `.unicode` | Every Unicode scalar value, the default |
| `.ascii` | The 128 ASCII characters |
| `.letters` | `A` to `Z`, then `a` to `z` |
| `.lowerCase` | `a` to `z` |
| `.upperCase` | `A` to `Z` |
| `.digits` | `0` to `9` |
| `.lettersAndDigits` | `0` to `9`, then the letters |

`.ascii` and `.unicode` put `0` to `Z` first, so a shrunk string reads as digits and capitals where it can, never as control characters a report cannot show. `Alphabet.of(characters)` builds one from a string, its characters simplest first:

```dart
final String path = draw(.string(alphabet: .of('ab/.')), label: 'path');
```

## Collections

`.list(element)` draws a list of `element`'s values, from `minLength` to `maxLength` long, with no maximum where `maxLength` is null. It shrinks by dropping elements whole, then shrinking each that is left.

`.set(element)` draws a set by `==`, from `minSize` to `maxSize`. A draw that repeats an element the set holds is drawn again, up to three draws in all, after which the set ends where it stands, and rejects the run where it holds fewer than `minSize`. A set of a narrow element, such as a `minSize` of 10 over `.boolean()`, so rejects every run.

A map is a set of keys with a value drawn for each, or a list of pairs:

```dart
final Set<String> keys = draw(.set(.string(alphabet: .lowerCase)));
final Map<String, int> map = {for (final String key in keys) key: draw(.integer())};
```

## Choosing

`.element(values)` draws one of a list of values, and shrinks towards the first, so the simplest goes first. An enum's values are one:

```dart
final Weekday day = draw(.element(Weekday.values), label: 'day');
```

`.oneOf(generators)` draws a value of one of several generators, chosen before its value is drawn, and shrinks towards the first generator's simplest value:

```dart
final int n = draw(.oneOf([.integer(min: 0, max: 9), .integer()]), label: 'n');
```

## Building one's own

`Gen.build` turns a body that draws into a generator, for a type the property draws often or a value built from parts. Its body is synchronous, and draws from other generators as a property's body does:

```dart
typedef Point = ({int x, int y});

final Gen<Point> point = Gen.build(
  (draw) => (x: draw(.integer()), y: draw(.integer())),
);

final Gen<List<Point>> path = Gen.build((draw) {
  final Point start = draw(point);
  final int steps = draw(.integer(min: 0, max: 20));
  return [
    start,
    for (int i = 1; i <= steps; i++) (x: start.x + i, y: start.y),
  ];
});
```

A built generator shrinks with no shrinking code of its own, since it is made of the choices its draws made. Its simplest value is its body's on the simplest value of each generator it draws, here a point at the origin. Its body may call `assume` and `note` as a property's does.

`map` makes a generator of a function's values, and `filter` one of the values a test holds for:

```dart
final Gen<int> even = Gen.integer().map((n) => n * 2);
final Gen<String> word = Gen.string(alphabet: .lowerCase, minLength: 1)
    .filter((s) => s != 'grit');
```

A filter draws up to three times, keeping the first value its test holds for, and rejects the run where it holds for none. A filter that rarely passes rejects most runs, where a generator that draws only those values would reject none.

A generator a property needs in many tests is a top-level `final`, drawn by its name, `draw(point)`, since dot shorthand names `Gen`'s own static members alone.
