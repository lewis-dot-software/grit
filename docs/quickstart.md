---
type: knowledge
aliases: getting started, install, first property, tutorial, user guide
---

# Quickstart

This page installs grit, writes a property that fails, reads its report and replays the failure, then links a doc for each topic it touches. A property states what should hold for every input, and grit draws the inputs, searches for one that breaks the property, and shrinks it to its smallest failing case.

## Install

grit runs inside `package:test` on the Dart VM, from Dart 3.13. Until `v1.0.0` reaches pub.dev, a package pins a tag of grit's public repo as a dev dependency:

```yaml
dev_dependencies:
  grit:
    git:
      url: https://github.com/lewis-dot-software/grit
      ref: v0.3.4
  test: ^1.31.1
```

Then `dart pub get`.

## Write a property

A row encoder joins its fields with commas, and decoding a row it encoded should give the row back. In `test/row_test.dart`:

```dart
import 'package:grit/grit.dart';
import 'package:test/test.dart';

String encode(List<String> fields) => fields.join(',');

List<String> decode(String line) => line.split(',');

void main() {
  property('decoding an encoded row gives the row back', (draw) {
    final List<String> row = draw(
      .list(.string(alphabet: .ascii), minLength: 1),
      label: 'row',
    );
    expect(decode(encode(row)), row);
  });
}
```

`property` declares a test, as `test` does. Its body draws each input it needs by calling `draw` on a generator, here a list of at least one string of ASCII characters, and fails by throwing, as `expect` does. The label names the value in the report.

## Run it

`dart test` runs the property as it runs any test. grit runs the body 100 times on random inputs, and the first run that throws is a failure, which grit shrinks:

```text
The property failed. Its smallest failing case, shrunk in 199 steps over 27 ms:

It drew:
  row: [',']

It threw:
  Expected: [',']
    Actual: ['', '']
     Which: at location [0] is '' instead of ','

Replay this case alone with `settings: Settings(replay: 'grit1:0.1.1a.0.0')`.

Seed 27623897. The next search at this call site replays this failure first, so `settings: Settings(seed: 27623897)` repeats this search once `.dart_tool/grit/` no longer holds it.
```

The first failure grit found was a row of long random strings. Shrinking cut it to one field holding one comma, which decodes as two empty fields, and that is the bug. The report lists every value the body drew under its label, what the body threw, and two ways to run the failure again.

## Replay it

`dart test` again brings the same failure back at once. grit keeps each property's smallest failing case under `.dart_tool/grit/` and replays it before generating anything, so a fix is tried first against the case that broke the code.

To work on that one case alone, hand its token to the property's settings:

```dart
  property('decoding an encoded row gives the row back', (draw) {
    final List<String> row = draw(
      .list(.string(alphabet: .ascii), minLength: 1),
      label: 'row',
    );
    expect(decode(encode(row)), row);
  }, settings: Settings(replay: 'grit1:0.1.1a.0.0'));
```

The property now runs its body once, on that case, with no search and no shrinking:

```text
The property failed on the case its replay token names, run once with no shrinking:

It drew:
  row: [',']

It threw:
  Expected: [',']
    Actual: ['', '']
     Which: at location [0] is '' instead of ','

Remove `replay` from the settings to search for a failure again.
```

Once the encoder escapes its commas, the replay's run passes, and the test fails saying the token no longer reproduces a failure. A token is for debugging one case, so none left in the code stands in for the search. With `replay` removed, the property searches again.

## Topics

- [Properties](properties.md) - `property`, `forAll` inside a test that stands such as a `testWidgets`, and `runProperty`.
- [Drawing inputs](drawing.md) - drawing in the body, labels, `assume` and `note`.
- [Generators](generators.md) - grit's generators, and building one's own.
- [Failures](failures.md) - reading a report, shrinking and its budget, and the outcomes besides a failure.
- [Replay](replay.md) - the stored failure, tokens and seeds.
- [Settings](settings.md) - the run count, the seed, shrinking's budget and the replay token.
- [Outcomes](outcomes.md) - what a search comes to, as the types `runProperty` returns.
- [Coming from glados](from-glados.md) - glados's idioms in grit's terms.
