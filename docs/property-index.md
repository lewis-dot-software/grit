---
type: knowledge
aliases: properties, invariants, property tests, property numbers
---

# Property index

Every property the code holds, each by its number beside its property test, and its Lean declaration where it is proved. A section holds each part of the code, and a property sits under the part whose code holds it, the ones a reader most needs first. A number is the part's code and the property's place in its section, `ENG-1` and on, so it says at a glance which part holds the property, and none is worn twice.

A property's test wears its number and its words as its title. Where a property is checked over every small input as well as on grit, both tests wear them, in the one file its `Test:` line names.

## Engine

### ENG-1: The clock never changes a verdict

The clock never changes a verdict: the same seed passes or fails alike under any clock, and only the failure's size can differ.

Test: [test/engine/search_test.dart](../test/engine/search_test.dart)

### ENG-2: A failed outcome fails again on replay

A failed outcome's sequence fails again, the same way, when replayed.

Test: [test/engine/search_test.dart](../test/engine/search_test.dart)

### ENG-3: A failure gone on replay ends flaky

A body that fails once and not on replay ends flaky, never failed.

Test: [test/engine/search_test.dart](../test/engine/search_test.dart)

### ENG-4: One seed fills the same sequences

A search from one seed fills the same sequences in the same order.

Test: [test/engine/search_test.dart](../test/engine/search_test.dart)

### ENG-5: Errors of grit's own kept apart

An error grit's own code throws inside a draw ends the test as grit's error, never as the property's failure.

Test: [test/engine/search_test.dart](../test/engine/search_test.dart)

### ENG-6: Failures alike either way round

Two failures are alike read from either, or from neither.

Test: [test/engine/call_site_test.dart](../test/engine/call_site_test.dart)

### ENG-7: A failure alike itself

A failure is alike itself.

Test: [test/engine/call_site_test.dart](../test/engine/call_site_test.dart)

### ENG-8: Shortlex as a total order

For any two different sequences, exactly one is shortlex smaller than the other.

Test: [test/choice/choice_sequence_test.dart](../test/choice/choice_sequence_test.dart)

### ENG-9: The empty sequence smallest

The empty sequence is shortlex smaller than every other.

Test: [test/choice/choice_sequence_test.dart](../test/choice/choice_sequence_test.dart)

### ENG-10: Smaller sequences after in shortlex order

Every sequence is smaller than each one after it in shortlex order.

Test: [test/choice/choice_sequence_test.dart](../test/choice/choice_sequence_test.dart)

### ENG-11: A fixed source's choices in order

A fixed source:

- Hands a run exactly its sequence's choices in order.
- Ends a run that asks past its end overrun.
- Gives as its room the choices left of its sequence.

Test: [test/choice/choice_source_test.dart](../test/choice/choice_source_test.dart)

### ENG-12: A fixed choice above its bound

A fixed choice above the bound a generator now asks for ends the run rejected.

Test: [test/choice/choice_source_test.dart](../test/choice/choice_source_test.dart)

### ENG-13: A random fill within its bound and limit

A random fill:

- Never gives a choice above the bound asked for.
- Never gives more choices than its limit.
- Gives as its room the choices left of its limit.

Test: [test/choice/choice_source_test.dart](../test/choice/choice_source_test.dart)

### ENG-14: An early fill within its bound

An early run never fills a choice outside its bound, whatever fill it takes.

Test: [test/choice/choice_source_test.dart](../test/choice/choice_source_test.dart)

### ENG-15: An early fill within its zigzag

An early run never fills a distance outside its zigzag, whatever fill it takes.

Test: [test/choice/choice_source_test.dart](../test/choice/choice_source_test.dart)

### ENG-16: Named edges change no value

Naming a choice's edges changes no value a given sequence draws.

Test: [test/choice/choice_source_test.dart](../test/choice/choice_source_test.dart)

### ENG-17: One choice per zigzag distance

A zigzag stands for each distance from below its centre to above it at exactly one choice, which it finds from the distance.

Test: [test/choice/zigzag_test.dart](../test/choice/zigzag_test.dart)

### ENG-18: Larger choices further from the centre

A larger choice never stands for a distance nearer the centre.

Test: [test/choice/zigzag_test.dart](../test/choice/zigzag_test.dart)

### ENG-19: A zigzag's two ends

A zigzag's bound and its other end, beside its centre at 0, stand for its two ends.

Test: [test/choice/zigzag_test.dart](../test/choice/zigzag_test.dart)

## Generators

### GEN-1: One sequence draws one value

The same sequence always draws the same value.

Test: [test/gen/gen_test.dart](../test/gen/gen_test.dart)

### GEN-2: Simplest values from all-zero choices

Each of `.integer`, `.boolean`, `.list`, `.element`, `.string`, `.oneOf`, `.set` and `.float` draws its documented simplest value from all-zero choices.

Test: [test/gen/gen_test.dart](../test/gen/gen_test.dart)

### GEN-3: A filter only draws what it accepts

A filtered generator only ever draws a value its predicate accepts, and rejects the run once its retries are spent.

Test: [test/gen/gen_test.dart](../test/gen/gen_test.dart)

### GEN-4: A draw's text kept as returned

A draw keeps each value's text as the draw returned it, whatever the body does to the value after.

Test: [test/gen/gen_test.dart](../test/gen/gen_test.dart)

### GEN-5: Integers within range towards their target

An integer always draws within its range, and a smaller choice never draws a value further from its target.

Test: [test/gen/integer_test.dart](../test/gen/integer_test.dart)

### GEN-6: One choice per integer value

An integer draws each value of its range from exactly one choice.

Test: [test/gen/integer_test.dart](../test/gen/integer_test.dart)

### GEN-7: Deleting a list element's span

Deleting one element's span from a list's record draws the same list with that element removed.

Test: [test/gen/list_test.dart](../test/gen/list_test.dart)

### GEN-8: A list of like elements ends in its run

A list whose elements each cost alike ends inside its run, every "one more" choice filled as one more, wherever the room it starts with fits its minimum, or one element where that is 0, and a choice more.

Test: [test/gen/list_test.dart](../test/gen/list_test.dart)

### GEN-9: Sets within their size bounds

Every set drawn holds from its minimum to its maximum elements.

Test: [test/gen/set_test.dart](../test/gen/set_test.dart)

### GEN-10: Deleting a set element's span

Deleting one element's span from the record of a set larger than its minimum, where no later draw repeats that element, draws the set without that element.

Test: [test/gen/set_test.dart](../test/gen/set_test.dart)

### GEN-11: Strings within their bounds and alphabet

Every string drawn has from its minimum to its maximum code points, and holds only its alphabet's.

Test: [test/gen/string_test.dart](../test/gen/string_test.dart)

### GEN-12: Every allowed string reachable

Every string its length bounds and alphabet allow is drawn by some sequence.

Test: [test/gen/string_test.dart](../test/gen/string_test.dart)

### GEN-13: Deleting a code point's span

Deleting one code point's span from the record of a string longer than its minimum draws the string without that code point.

Test: [test/gen/string_test.dart](../test/gen/string_test.dart)

### GEN-14: A preset's characters each at one index

A string draws each of a preset's characters at one index, and nothing else.

Test: [test/gen/string_test.dart](../test/gen/string_test.dart)

### GEN-15: A drawn string's text as a Dart literal

Whatever a drawn string holds, its text is a single-quoted Dart literal of printable ASCII alone, which reads back as the string.

Test: [test/gen/text_test.dart](../test/gen/text_test.dart)

### GEN-16: Values of `oneOf` from its generators

Every value `oneOf` draws is one of its generators' values, and choices of 0 draw its first generator's simplest.

Test: [test/gen/one_of_test.dart](../test/gen/one_of_test.dart)

### GEN-17: Floats within their bounds and flags

Every float drawn:

- Is NaN only where its `nan` flag allows it.
- Infinite only where its bounds and `infinite` flag allow it.
- And otherwise lies within its bounds.

Test: [test/gen/float_test.dart](../test/gen/float_test.dart)

### GEN-18: Every allowed float reachable

Every float its bounds and flags allow is drawn by some sequence.

Test: [test/gen/float_test.dart](../test/gen/float_test.dart)

### GEN-19: Simpler floats from smaller sequences

Of two floats in range, the simpler is drawn by the smaller sequence:

- The positive before the negative.
- Then a whole number before a fraction.
- Then the smaller magnitude before the larger.
- With the infinities and NaN after every finite float.

Test: [test/gen/float_test.dart](../test/gen/float_test.dart)

### GEN-20: A fraction's form and an infinity's

A float names a form, where the range holds it and by a smaller sequence, as follows:

- A fraction names the whole number of its sign at its magnitude rounded up.
- An infinity names the finite double of its sign of the largest magnitude.
- No other float names one.

Test: [test/gen/float_test.dart](../test/gen/float_test.dart)

## Shrinker

### SHR-1: Shrinking always ends

Shrinking always ends, whatever the oracle answers.

Test: [test/shrink/shrink_test.dart](../test/shrink/shrink_test.dart)

Lean: `Grit.told_always_ends` in [lean/Shrink/Ending.lean](../lean/Shrink/Ending.lean)

### SHR-2: Only failures held as current

The current sequence is always the record the first failure's run read, or one a candidate's run read when told it failed.

Test: [test/shrink/shrink_test.dart](../test/shrink/shrink_test.dart)

Lean: `Grit.told_holds_only_failures` in [lean/Shrink/Failing.lean](../lean/Shrink/Failing.lean)

### SHR-3: Accepted candidates shortlex smaller

Every accepted candidate's record is shortlex smaller than the sequence it replaces.

Test: [test/shrink/shrink_test.dart](../test/shrink/shrink_test.dart)

### SHR-4: The result a fixed point

Shrinking the result again accepts nothing, so the result is a fixed point.

Test: [test/shrink/shrink_test.dart](../test/shrink/shrink_test.dart)

### SHR-5: No larger than the first failure

A failed outcome's sequence is never larger than the first failure found.

Test: [test/engine/search_test.dart](../test/engine/search_test.dart)

### SHR-6: No larger than any failing record found

A failed outcome's sequence is never larger than any failing record shrinking found.

Test: [test/engine/search_test.dart](../test/engine/search_test.dart)

### SHR-7: Candidates read smaller records

Every candidate's run reads a record smaller than each record read before it by a run that failed as the first failure did.

Test: [test/engine/search_test.dart](../test/engine/search_test.dart)

### SHR-8: Shrinking within its step bound

Under shrinking's bound of steps:

- Shrinking never runs more steps than the bound.
- An outcome whose bound ran out names that bound.
- An outcome's sequence is the choices its final replay read.

Test: [test/engine/search_test.dart](../test/engine/search_test.dart)

### SHR-9: Another error or frame never accepted

A candidate that fails with another error type or from another frame is never accepted.

Test: [test/engine/search_test.dart](../test/engine/search_test.dart)

### SHR-10: No candidate run twice

A search runs no candidate twice, and runs each candidate the step function proposes once.

Test: [test/engine/search_test.dart](../test/engine/search_test.dart)

### SHR-11: Shrink stepping as its proved model

Shrink proposes each candidate and ends as the Lean model does, whatever the oracle answers.

Test: [test/shrink/shrink_model_test.dart](../test/shrink/shrink_model_test.dart)

### SHR-12: Zeroing beneath a list's draw

Zeroing every draw beneath a list's in its record draws a list as long, each element its simplest value.

Test: [test/shrink/pass_test.dart](../test/shrink/pass_test.dart)

### SHR-13: Swapping sibling spans

Swapping two sibling spans in a list's record draws the list with those two elements swapped.

Test: [test/shrink/pass_test.dart](../test/shrink/pass_test.dart)

### SHR-14: Deleting the last span by width

Deleting the last span proposes at most two candidates per width, however long the sequence.

Test: [test/shrink/pass_test.dart](../test/shrink/pass_test.dart)

## Replay

### REP-1: A token's replay runs once, store untouched

A token's replay runs the body once and leaves the store as it stood.

Test: [test/engine/search_test.dart](../test/engine/search_test.dart)

### REP-2: A report's token replays the failure

The token a failure's report prints replays a run that fails as the reported one did.

Test: [test/api/property_run_test.dart](../test/api/property_run_test.dart)

### REP-3: The stored sequence after a search

After a search with no token, its call site's stored sequence is the smallest failing sequence of a failed outcome, and nothing after any other.

Test: [test/engine/search_test.dart](../test/engine/search_test.dart)

### REP-4: A stored failure never reported larger

A failure found from a stored sequence is never reported larger than that sequence.

Test: [test/engine/search_test.dart](../test/engine/search_test.dart)

### REP-5: A saved sequence loads under its key alone

A sequence saved under a key loads under that key until it is deleted, and under no other.

Test: [test/store/file_store_test.dart](../test/store/file_store_test.dart)

### REP-6: A token decodes to its sequence

Decoding the token of any sequence gives that sequence back.

Test: [test/choice/token_test.dart](../test/choice/token_test.dart)

### REP-7: One token per sequence

Text that decodes is the one token its sequence encodes to, so no two tokens name one sequence.

Test: [test/choice/token_test.dart](../test/choice/token_test.dart)

### REP-8: A token as one safe line

The token of any sequence:

- Is one line of ASCII.
- Safe inside a Dart string literal.
- And opens with its format's version.

Test: [test/choice/token_test.dart](../test/choice/token_test.dart)

### REP-9: Text that is no token never decodes

Text that is no token, or a token of another format, never decodes to a sequence, and its error says which.

Test: [test/choice/token_test.dart](../test/choice/token_test.dart)

### REP-10: A warning never changes a verdict

A warning never changes a verdict: one seed passes or fails alike whatever the clock reads.

Test: [test/engine/search_test.dart](../test/engine/search_test.dart)

### REP-11: A slow property warned

A property is warned slow exactly where its runs' mean time times the run count passes 5 s and the mean passes its expected run time.

Test: [test/engine/search_test.dart](../test/engine/search_test.dart)

### REP-12: Mostly invalid runs warned

A search is warned of its invalid runs exactly where they outnumber those that returned and it did not give up.

Test: [test/engine/search_test.dart](../test/engine/search_test.dart)

### REP-13: An outcome's warnings read-only

An outcome's warnings cannot be changed by whoever reads them.

Test: [test/engine/outcome_test.dart](../test/engine/outcome_test.dart)

## Runner

### RUN-1: The seed named only where it repeats

A report says its seed repeats the search only where that search generated from the seed.

Test: [test/report/report_test.dart](../test/report/report_test.dart)

### RUN-2: Notes and values printed line for line

Whatever a note's or a drawn value's text holds, the report prints it:

- Under its heading line for line.
- Two spaces opening each line that is not empty.
- With its trailing whitespace trimmed and no line the indent alone.

Test: [test/report/report_test.dart](../test/report/report_test.dart)

### RUN-3: A settings source read back

A settings source built from a seed and settings reads back that seed and those settings.

Test: [test/api/settings_source_test.dart](../test/api/settings_source_test.dart)
