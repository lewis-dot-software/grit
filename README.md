# grit

grit is a property-based testing library for Dart. You state what should hold for every input, and grit generates the inputs, finds one that breaks it, and shrinks it to the smallest case that still fails. Shrinking always runs within a budget, so a failing test ends quickly with the clearest example grit can give, never hours later. Named for generate, reduce, invariant, test, and for the toughness a test suite needs.

**Status:** v0.4.0 Soak is the current milestone.

<!-- office doc index -->

## Docs

- [Architecture](docs/architecture.md) `knowledge` - A property's body draws its inputs through a choice source, and every choice it makes is recorded as a natural number.
- [Shrinker proofs](docs/proofs.md) `knowledge` - The shrinker's step function is tested against a model of it written in Lean, and the properties Dan ruled on are proved of that model, by the office's proofs method (`standard/proofs.md` in the office).

<!-- /office doc index -->

## AI usage

Claude writes the code, far faster than I could by hand, but the design and the standard it's held to are mine. It runs inside tooling I've built on top of Claude Code, so every change is planned before it's written, then passes independent review, the full test suite and a strict quality gate before it reaches me. I review every line and send it back until it meets that standard, which is why every commit is mine. `CLAUDE.md` is gitignored because it holds details of my own setup, not to hide AI's part.

## Contributing

This repo is a public copy of my private workspace, so nothing is ever merged here. Bug reports and feature requests are welcome as GitHub issues. A pull request is read as a proposal, and anything taken up is rebuilt and credited.
