# grit

grit is a property-based testing library for Dart. You state what should hold for every input, and grit generates the inputs, finds one that breaks it, and shrinks it to the smallest case that still fails. Shrinking always runs within a budget, so a failing test ends quickly with the clearest example grit can give, never hours later. Named for generate, reduce, invariant, test, and for the toughness a test suite needs.

**Status:** v0.1.0 Engine is the current milestone.

<!-- office doc index -->

## Docs

- [Architecture](docs/architecture.md) `knowledge` - A property's body draws its inputs through a choice source, and every choice it makes is recorded as a natural number.

<!-- /office doc index -->
