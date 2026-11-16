---
type: knowledge
aliases: token, stored failure, store, .dart_tool/grit, seed, reproducing a failure
---

# Replay

grit runs a failure again three ways: the store's replay, a token and a seed. The store replays each property's last failure before its next search, on its own. A token replays one case alone, on demand. A seed repeats a whole search.

## The stored failure

A search that fails keeps its smallest failing case in a file of its own under `.dart_tool/grit/`, in the package `dart test` runs in. The next search of the same property replays that case before it generates anything. Where the case still fails, the search shrinks from it, and its report says it was first found by replaying an earlier search's failure. Where it no longer fails, the search generates as usual. A search that ends any way but a failure leaves nothing stored for its property, so a fixed bug's case is gone once the property passes.

Each stored failure is keyed by its call site: the line `property`, `forAll` or `runProperty` is called from, with each frame of the consumer's package beneath it. So:

- Edits above the call: an edit that moves the line loses its stored failure, and the next search generates afresh.
- Helpers: a property declared inside a helper is keyed by where the helper is called, so each call keeps a failure of its own.
- Loops: properties declared from one line in a loop share one key, and replay each other's failure.

The store is local to a checkout, since `.dart_tool/` is kept out of git, so a fresh clone or a CI run searches afresh. Deleting `.dart_tool/grit/` clears every stored failure. grit writes nothing anywhere else.

A stored file that is no token grit reads is deleted, and the search warns of it and generates afresh ([failures.md](failures.md)).

## Tokens

A failure's report prints its case's token, the case as one line of text:

```text
Replay this case alone with `settings: Settings(replay: 'grit1:0.1.1a.0.0')`.
```

A property with `replay` in its settings runs its body once, on that case, in place of a search: no generation, no shrinking, and no stored failure read or written. Where the body throws, the test fails with the case's report, unshrunk. Where it does not, the test fails saying the token no longer reproduces a failure and how its run ended, so a token never stands in for the search once its bug is fixed. A token is for debugging one case, and comes out once the case passes.

A token names a run's choices, not its values: the format, `grit1`, then each choice in base 36, joined by dots. It replays the same values only while the body draws the same way, so a change to a generator's bounds or to the order of the draws replays other values from the same choices.

`Settings(replay: ...)` throws an `ArgumentError` for text that is no token, saying which kind of `Undecodable` it is:

- `NotAToken`: text that is no token of any format.
- `OtherFormat`: a token of a `format` other than the one this version of grit reads, such as one a later version printed.

## Seeds

Each search draws a seed afresh unless its settings name one. A report prints the seed with the settings that repeat its search:

```text
Seed 27623897. The next search at this call site replays this failure first, so `settings: Settings(seed: 27623897)` repeats this search once `.dart_tool/grit/` no longer holds it.
```

One seed under the same other settings repeats one search exactly, run for run, shrinking aside where its time runs out. A failing search's seed repeats it only once the stored failure is gone, since the store's replay runs first and draws nothing from the seed. A report of a failure first found from the store names no seed for the same reason.

A fixed seed makes a property's search the same on every run, so it finds nothing new. It suits repeating one search while debugging, and a search left to draw its own seed covers more inputs with every run of the suite.
