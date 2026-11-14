# grit

grit is a property-based testing library for Dart. You state what should hold for every input, and grit generates the inputs, finds one that breaks it, and shrinks it to the smallest case that still fails. Shrinking always runs within a budget, so a failing test ends quickly with the clearest example grit can give, never hours later. Named for generate, reduce, invariant, test, and for the toughness a test suite needs.

**Status:** v0.4.0 Soak is the current milestone.

<!-- office doc index -->

## Docs

- [Architecture](docs/architecture.md) `knowledge` - A property's body draws its inputs through a choice source, and every choice it makes is recorded as a natural number.
- [Shrinker proofs](docs/proofs.md) `knowledge` - The shrinker's step function is tested against a model of it written in Lean, and the properties Dan ruled on are proved of that model, by the office's proofs method (`standard/proofs.md` in the office).

<!-- /office doc index -->
