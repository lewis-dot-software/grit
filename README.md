# grit

grit is a property-based testing library for Dart. You state what should hold for every input, and grit generates the inputs, finds one that breaks it, and shrinks it to the smallest case that still fails. Shrinking always runs within a budget, so a failing test ends quickly with the clearest example grit can give, never hours later. Named for generate, reduce, invariant, test, and for the toughness a test suite needs.

## Install

grit runs inside `package:test` on the Dart VM, from Dart 3.13. Until `v1.0.0` reaches pub.dev, pin a tag of this repo as a dev dependency:

```yaml
dev_dependencies:
  grit:
    git:
      url: https://github.com/lewis-dot-software/grit
      ref: v0.3.4
```

## A property

```dart
import 'package:grit/grit.dart';
import 'package:test/test.dart';

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

A property's body draws each input as it needs it, so no arity is chosen up front and an input can depend on one drawn before it. A failure is shrunk to its smallest case, kept under `.dart_tool/grit/` and replayed first on the next run, and its report prints a token that replays the case alone.

The [quickstart](docs/quickstart.md) writes, runs and replays a failing property, and links a doc per topic.

<!-- office doc index -->

## Docs

- [Architecture](docs/architecture.md) - A property's body draws its inputs through a choice source, and every choice it makes is recorded as a natural number.
- [Coming from glados](docs/from-glados.md) - glados hands a property its inputs as arguments, from generators chosen up front, and grit's body draws them as it needs them.
- [Drawing inputs](docs/drawing.md) - A property's body draws each input as it needs it, by calling its `Draw` on a generator.
- [Failures](docs/failures.md) - A failing property's report gives its smallest failing case: what the body drew, what it noted and what it threw, how shrinking ended, and how to run the case again.
- [Generators](docs/generators.md) - A generator is a `Gen<T>`: it makes a value of `T` from a run's random choices, and the value shrinks as those choices do.
- [Outcomes](docs/outcomes.md) - A search comes to one `Outcome`, a sealed type with a case per way it can end.
- [Properties](docs/properties.md) - A property is declared one of three ways: `property` as a test of its own, `forAll` inside a test that already stands, and `runProperty` for its outcome as a value, with no test failed.
- [Quickstart](docs/quickstart.md) - This page installs grit, writes a property that fails, reads its report and replays the failure, then links a doc for each topic it touches.
- [Replay](docs/replay.md) - grit runs a failure again three ways: the store's replay, a token and a seed.
- [Settings](docs/settings.md) - A property's `Settings` say how it is searched, each with a default no property has to change.
- [Shrinker proofs](docs/proofs.md) - The shrinker's step function is tested against a model of it written in Lean, and the properties Dan ruled on are proved of that model, by the office's proofs method (`standard/proofs.md` in the office).

<!-- /office doc index -->

## AI usage

Nothing here is "vibe-coded". Claude writes the code, far faster than I could by hand, but the design and the standard it's held to are mine. It runs inside tooling I've built on top of Claude Code, so every change is planned before it's written, then passes independent review, the full test suite and a strict quality gate before it reaches me. I review every line and send it back until it meets that standard, which is why every commit is mine. `CLAUDE.md` is gitignored because it holds details of my own setup, not to hide AI's part.

## Contributing

This repo is a public mirror of a private one, so nothing is ever merged here. Bug reports and feature requests are welcome as GitHub issues. A pull request is read as a proposal, and anything taken up is rebuilt and credited.
